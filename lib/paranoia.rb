require 'active_record' unless defined? ActiveRecord

module Paranoia
  def self.included(klazz)
    klazz.extend Query
    klazz.extend Callbacks
  end

  module Query
    def paranoid?
      true
    end


    def with_deleted
      scoped.tap { |x| x.default_scoped = false }
    end

    def only_deleted
      with_deleted.where("#{self.table_name}.#{paranoia_column} IS NOT NULL")
    end
    alias :deleted :only_deleted

    def restore(id, opts = {})
      if id.is_a?(Array)
        id.map { |one_id| restore(one_id, opts) }
      else
        only_deleted.find(id).restore!(opts)
      end
    end
  end

  module Callbacks
    def self.extended(klazz)
      klazz.define_callbacks :restore

      klazz.define_singleton_method("before_restore") do |*args, &block|
        set_callback(:restore, :before, *args, &block)
      end

      klazz.define_singleton_method("around_restore") do |*args, &block|
        set_callback(:restore, :around, *args, &block)
      end

      klazz.define_singleton_method("after_restore") do |*args, &block|
        set_callback(:restore, :after, *args, &block)
      end
    end
  end

  def destroy
    callbacks_result = run_callbacks(:destroy) { touch_paranoia_column(true) }
    callbacks_result ? self : false
  end

  def delete
    return if new_record?
    touch_paranoia_column(false)
  end

  def restore!(opts = {})
    ActiveRecord::Base.transaction do
      run_callbacks(:restore) do
        update_column paranoia_column, nil
        restore_associated_records if opts[:recursive]
      end
    end
  end
  alias :restore :restore!

  def destroyed?
    !!send(paranoia_column)
  end

  alias :deleted? :destroyed?

  private

  # touch paranoia column.
  # insert time to paranoia column.
  # @param with_transaction [Boolean] exec with ActiveRecord Transactions.
  def touch_paranoia_column(with_transaction=false)
    # This method is (potentially) called from really_destroy
    # The object the method is being called on may be frozen
    # Let's not touch it if it's frozen.
    unless self.frozen?
      if with_transaction
        with_transaction_returning_status { touch(paranoia_column) }
      else
        touch(paranoia_column)
      end
    end
  end

  # restore associated records that have been soft deleted when
  # we called #destroy
  def restore_associated_records
    destroyed_associations = self.class.reflect_on_all_associations.select do |association|
      association.options[:dependent] == :destroy
    end

    destroyed_associations.each do |association|
      association_data = send(association.name)

      unless association_data.nil?
        if association_data.paranoid?
          if association.collection?
            association_data.only_deleted.each { |record| record.restore(:recursive => true) }
          else
            association_data.restore(:recursive => true)
          end
        end
      end
    end
  end
end

class ActiveRecord::Base
  def self.acts_as_paranoid(options={})
    alias :really_destroyed? :destroyed?
    alias :ar_destroy :destroy
    alias :destroy! :ar_destroy
    alias :delete! :delete
    def really_destroy!
      dependent_reflections = self.reflections.select do |name, reflection|
        reflection.options[:dependent] == :destroy
      end
      if dependent_reflections.any?
        dependent_reflections.each do |name, _|
          associated_records = self.send(name)
          # Paranoid models will have this method, non-paranoid models will not
          associated_records = associated_records.with_deleted if associated_records.respond_to?(:with_deleted)
          associated_records.each(&:really_destroy!)
        end
      end
      destroy!
    end

    include Paranoia
    class_attribute :paranoia_column

    self.paranoia_column = options[:column] || :deleted_at
    default_scope { where(self.quoted_table_name + ".#{paranoia_column} IS NULL") }

    before_restore {
      self.class.notify_observers(:before_restore, self) if self.class.respond_to?(:notify_observers)
    }
    after_restore {
      self.class.notify_observers(:after_restore, self) if self.class.respond_to?(:notify_observers)
    }
  end

  def self.paranoid?
    false
  end

  def paranoid?
    self.class.paranoid?
  end

  # Override the persisted method to allow for the paranoia gem.
  # If a paranoid record is selected, then we only want to check
  # if it's a new record, not if it is "destroyed".
  def persisted?
    paranoid? ? !new_record? : super
  end

  private

  def paranoia_column
    self.class.paranoia_column
  end
end


require 'paranoia/rspec' if defined? RSpec

module ActiveRecord
  module Validations
    class UniquenessValidator < ActiveModel::EachValidator
      protected
      def build_relation_with_paranoia(klass, table, attribute, value)
        relation = build_relation_without_paranoia(klass, table, attribute, value)
        if klass.respond_to?(:paranoia_column)
          relation.and(klass.arel_table[klass.paranoia_column].eq(nil))
        else
          relation
        end
      end
      alias_method_chain :build_relation, :paranoia
    end
  end
end
