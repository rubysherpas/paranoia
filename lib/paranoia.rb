require 'active_record' unless defined? ActiveRecord

module Paranoia
  def self.included(klazz)
    klazz.extend Query
    klazz.extend Callbacks
  end

  module Query
    def paranoid? ; true ; end

    def with_deleted
      if ActiveRecord::VERSION::STRING >= "4.1"
        unscope where: paranoia_indexed_column
      else
        all.tap { |x| x.default_scoped = false }
      end
    end

    def only_deleted
      with_deleted.where.not(paranoia_indexed_column => paranoia_false_value)
    end
    alias :deleted :only_deleted

    def restore(id, opts = {})
      if id.is_a?(Array)
        id.map { |one_id| restore(one_id, opts) }
      else
        only_deleted.find(id).restore!(opts)
      end
    end

    private

    def paranoia_false_value
      (paranoia_indexed_column == paranoia_column) ? nil : 0
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
    callbacks_result = transaction do
      run_callbacks(:destroy) do
        touch_paranoia_column
      end
    end
    callbacks_result ? self : false
  end

  # As of Rails 4.1.0 +destroy!+ will no longer remove the record from the db
  # unless you touch the paranoia column before.
  # We need to override it here otherwise children records might be removed
  # when they shouldn't
  if ActiveRecord::VERSION::STRING >= "4.1"
    def destroy!
      destroyed? ? super : destroy || raise(ActiveRecord::RecordNotDestroyed)
    end
  end

  def delete
    return if new_record?
    touch_paranoia_column(false)
  end

  def restore!(opts = {})
    ActiveRecord::Base.transaction do
      run_callbacks(:restore) do
        update_column paranoia_column, nil
        update_column(paranoia_flag_column, false) if paranoia_flag_column
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

  def mark_columns_deleted
    update_column(paranoia_flag_column, true) if paranoia_flag_column
    touch(paranoia_column)
  end

  # touch paranoia column, update flag column if necessary
  # insert time to paranoia column.
  # @param with_transaction [Boolean] exec with ActiveRecord Transactions.
  def touch_paranoia_column(with_transaction=false)
    # This method is (potentially) called from really_destroy
    # The object the method is being called on may be frozen
    # Let's not touch it if it's frozen.
    unless self.frozen?
      if with_transaction
        with_transaction_returning_status do
          mark_columns_deleted
        end
      else
        mark_columns_deleted
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
    alias :destroy! :destroy
    alias :delete! :delete
    def really_destroy!
      dependent_reflections = self.class.reflections.select do |name, reflection|
        reflection.options[:dependent] == :destroy
      end
      if dependent_reflections.any?
        dependent_reflections.each do |name, _|
          associated_records = self.send(name)
          # Paranoid models will have this method, non-paranoid models will not
          associated_records = associated_records.with_deleted if associated_records.respond_to?(:with_deleted)
          associated_records.each(&:really_destroy!)
          self.send(name).reload
        end
      end
      touch_paranoia_column if ActiveRecord::VERSION::STRING >= "4.1"
      destroy!
    end

    include Paranoia
    class_attribute :paranoia_column
    class_attribute :paranoia_flag_column
    class_attribute :paranoia_indexed_column

    self.paranoia_column = options[:column] || :deleted_at
    self.paranoia_flag_column = options[:flag_column] || nil
    self.paranoia_indexed_column = options[:indexed_column] || paranoia_column
    default_scope { where(paranoia_indexed_column => paranoia_false_value) }

    before_restore {
      self.class.notify_observers(:before_restore, self) if self.class.respond_to?(:notify_observers)
    }
    after_restore {
      self.class.notify_observers(:after_restore, self) if self.class.respond_to?(:notify_observers)
    }
  end

  # Please do not use this method in production.
  # Pretty please.
  def self.I_AM_THE_DESTROYER!
    # TODO: actually implement spelling error fixes
    puts %Q{
      Sharon: "There should be a method called I_AM_THE_DESTROYER!"
      Ryan:   "What should this method do?"
      Sharon: "It should fix all the spelling errors on the page!"
}
  end

  def self.paranoid? ; false ; end
  def paranoid? ; self.class.paranoid? ; end

  # Override the persisted method to allow for the paranoia gem.
  # If a paranoid record is selected, then we only want to check
  # if it's a new record, not if it is "destroyed".
  def persisted?
    paranoid? ? !new_record? : super
  end

  private

  def paranoia_flag_column
    self.class.paranoia_flag_column
  end

  def paranoia_indexed_column
    self.class.paranoia_indexed_column
  end

  def paranoia_column
    self.class.paranoia_column
  end
end

require 'paranoia/rspec' if defined? RSpec
