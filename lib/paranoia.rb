require 'active_record' unless defined? ActiveRecord

module Paranoia
  @@default_sentinel_value = nil

  # Change default_sentinel_value in a rails initilizer
  def self.default_sentinel_value=(val)
    @@default_sentinel_value = val
  end

  def self.default_sentinel_value
    @@default_sentinel_value
  end

  def self.included(klazz)
    klazz.extend Query
    klazz.extend Callbacks
  end

  module Query
    def paranoid? ; true ; end

    def with_deleted
      if ActiveRecord::VERSION::STRING >= "4.1"
        return unscope where: paranoia_column
      end
      all.tap { |x| x.default_scoped = false }
    end

    def only_deleted
      if paranoia_sentinel_value.nil?
        return with_deleted.where.not(paranoia_column => paranoia_sentinel_value)
      end
      # if paranoia_sentinel_value is not null, then it is possible that
      # some deleted rows will hold a null value in the paranoia column
      # these will not match != sentinel value because "NULL != value" is
      # NULL under the sql standard
      quoted_paranoia_column = connection.quote_column_name(paranoia_column)
      with_deleted.where("#{quoted_paranoia_column} IS NULL OR #{quoted_paranoia_column} != ?", paranoia_sentinel_value)
    end
    alias :deleted :only_deleted

    def restore(id_or_ids, opts = {})
      ids = Array(id_or_ids).flatten
      any_object_instead_of_id = ids.any? { |id| ActiveRecord::Base === id }
      if any_object_instead_of_id
        ids.map! { |id| ActiveRecord::Base === id ? id.id : id }
        ActiveSupport::Deprecation.warn("You are passing an instance of ActiveRecord::Base to `restore`. " \
                                        "Please pass the id of the object by calling `.id`")
      end
      ids.map { |id| only_deleted.find(id).restore!(opts) }
    end
  end

  module Callbacks
    def self.extended(klazz)
      [:restore, :real_destroy].each do |callback_name|
        klazz.define_callbacks callback_name

        klazz.define_singleton_method("before_#{callback_name}") do |*args, &block|
          set_callback(callback_name, :before, *args, &block)
        end

        klazz.define_singleton_method("around_#{callback_name}") do |*args, &block|
          set_callback(callback_name, :around, *args, &block)
        end

        klazz.define_singleton_method("after_#{callback_name}") do |*args, &block|
          set_callback(callback_name, :after, *args, &block)
        end
      end
    end
  end

  def destroy
    transaction do
      run_callbacks(:destroy) do
        result = delete
        next result unless result && ActiveRecord::VERSION::STRING >= '4.2'
        each_counter_cached_associations do |association|
          foreign_key = association.reflection.foreign_key.to_sym
          next if destroyed_by_association && destroyed_by_association.foreign_key.to_sym == foreign_key
          next unless send(association.reflection.name)
          association.decrement_counters
        end
        result
      end
    end
  end

  def delete
    raise ActiveRecord::ReadOnlyRecord, "#{self.class} is marked as readonly" if readonly?
    if persisted?
      # if a transaction exists, add the record so that after_commit
      # callbacks can be run
      add_to_transaction
      update_columns(paranoia_destroy_attributes)
    elsif !frozen?
      assign_attributes(paranoia_destroy_attributes)
    end
    self
  end

  def restore!(opts = {})
    self.class.transaction do
      run_callbacks(:restore) do
        # Fixes a bug where the build would error because attributes were frozen.
        # This only happened on Rails versions earlier than 4.1.
        noop_if_frozen = ActiveRecord.version < Gem::Version.new("4.1")
        if (noop_if_frozen && !@attributes.frozen?) || !noop_if_frozen
          write_attribute paranoia_column, paranoia_sentinel_value
          update_columns(paranoia_restore_attributes)
          touch
        end
        restore_associated_records if opts[:recursive]
      end
    end

    self
  end
  alias :restore :restore!

  def paranoia_destroyed?
    send(paranoia_column) != paranoia_sentinel_value
  end
  alias :deleted? :paranoia_destroyed?

  def really_destroy!
    transaction do
      run_callbacks(:real_destroy) do
        dependent_reflections = self.class.reflections.select do |name, reflection|
          reflection.options[:dependent] == :destroy
        end
        if dependent_reflections.any?
          dependent_reflections.each do |name, reflection|
            association_data = self.send(name)
            # has_one association can return nil
            # .paranoid? will work for both instances and classes
            next unless association_data && association_data.paranoid?
            if reflection.collection?
              next association_data.with_deleted.each(&:really_destroy!)
            end
            association_data.really_destroy!
          end
        end
        write_attribute(paranoia_column, current_time_from_proper_timezone)
        destroy_without_paranoia
      end
    end
  end

  private

  def paranoia_restore_attributes
    {
      paranoia_column => paranoia_sentinel_value
    }
  end

  def paranoia_destroy_attributes
    {
      paranoia_column => current_time_from_proper_timezone
    }
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

      if association_data.nil? && association.macro.to_s == "has_one"
        association_class_name = association.klass.name
        association_foreign_key = association.foreign_key

        if association.type
          association_polymorphic_type = association.type
          association_find_conditions = { association_polymorphic_type => self.class.name.to_s, association_foreign_key => self.id }
        else
          association_find_conditions = { association_foreign_key => self.id }
        end

        association_class = association_class_name.constantize
        if association_class.paranoid?
          association_class.only_deleted.where(association_find_conditions).first.try!(:restore, recursive: true)
        end
      end
    end

    clear_association_cache if destroyed_associations.present?
  end
end

class ActiveRecord::Base
  def self.acts_as_paranoid(options={})
    alias :really_destroyed? :destroyed?
    alias :really_delete :delete
    alias :destroy_without_paranoia :destroy

    include Paranoia
    class_attribute :paranoia_column, :paranoia_sentinel_value

    self.paranoia_column = (options[:column] || :deleted_at).to_s
    self.paranoia_sentinel_value = options.fetch(:sentinel_value) { Paranoia.default_sentinel_value }
    def self.paranoia_scope
      where(paranoia_column => paranoia_sentinel_value)
    end
    default_scope { paranoia_scope }

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

  private

  def paranoia_column
    self.class.paranoia_column
  end

  def paranoia_sentinel_value
    self.class.paranoia_sentinel_value
  end
end

require 'paranoia/rspec' if defined? RSpec

module ActiveRecord
  module Validations
    class UniquenessValidator < ActiveModel::EachValidator
      protected
      def build_relation_with_paranoia(klass, table, attribute, value)
        relation = build_relation_without_paranoia(klass, table, attribute, value)
        return relation unless klass.respond_to?(:paranoia_column)
        relation.and(klass.arel_table[klass.paranoia_column].eq(klass.paranoia_sentinel_value))
      end
      alias_method_chain :build_relation, :paranoia
    end
  end
end
