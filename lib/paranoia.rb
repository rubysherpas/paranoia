require 'active_record' unless defined? ActiveRecord

if [ActiveRecord::VERSION::MAJOR, ActiveRecord::VERSION::MINOR] == [5, 2] ||
   ActiveRecord::VERSION::MAJOR > 5
  require 'paranoia/active_record_5_2'
end

module Paranoia
  @@default_sentinel_value = nil

  # Change default_sentinel_value in a rails initializer
  def self.default_sentinel_value=(val)
    @@default_sentinel_value = val
  end

  def self.default_sentinel_value
    @@default_sentinel_value
  end

  def self.included(klazz)
    klazz.extend Query
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
      # Scoping with the table_name is mandatory to avoid ambiguous errors when joining tables.
      scoped_quoted_paranoia_column = "#{connection.quote_table_name(self.table_name)}.#{connection.quote_column_name(paranoia_column)}"
      with_deleted.where("#{scoped_quoted_paranoia_column} IS NULL OR #{scoped_quoted_paranoia_column} != ?", paranoia_sentinel_value)
    end
    alias_method :deleted, :only_deleted

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

  def paranoia_destroy
    with_transaction_returning_status do
      result = run_callbacks(:destroy) do
        @_disable_counter_cache = paranoia_destroyed?
        result = paranoia_delete
        next result unless result && ActiveRecord::VERSION::STRING >= '4.2'
        each_counter_cached_associations do |association|
          foreign_key = association.reflection.foreign_key.to_sym
          next if destroyed_by_association && destroyed_by_association.foreign_key.to_sym == foreign_key
          next unless send(association.reflection.name)
          association.decrement_counters
        end
        @_trigger_destroy_callback = true
        @_disable_counter_cache = false
        result
      end
      raise ActiveRecord::Rollback, "Not destroyed" unless paranoia_destroyed?
      result
    end || false
  end
  alias_method :destroy, :paranoia_destroy

  def paranoia_destroy!
    paranoia_destroy ||
      raise(ActiveRecord::RecordNotDestroyed.new("Failed to destroy the record", self))
  end

  def trigger_transactional_callbacks?
    super || @_trigger_destroy_callback && paranoia_destroyed?
  end

  def paranoia_delete
    raise ActiveRecord::ReadOnlyRecord, "#{self.class} is marked as readonly" if readonly?
    if persisted?
      # if a transaction exists, add the record so that after_commit
      # callbacks can be run
      add_to_transaction
      paranoia_update_columns(paranoia_destroy_attributes)
    elsif !frozen?
      assign_attributes(paranoia_destroy_attributes)
    end
    self
  end
  alias_method :delete, :paranoia_delete

  def restore!(opts = {})
    self.class.transaction do
      run_callbacks(:restore) do
        recovery_window_range = get_recovery_window_range(opts)
        # Fixes a bug where the build would error because attributes were frozen.
        # This only happened on Rails versions earlier than 4.1.
        noop_if_frozen = ActiveRecord.version < Gem::Version.new("4.1")
        if within_recovery_window?(recovery_window_range) && ((noop_if_frozen && !@attributes.frozen?) || !noop_if_frozen)
          @_disable_counter_cache = !paranoia_destroyed?
          write_attribute paranoia_column, paranoia_sentinel_value
          paranoia_update_columns(paranoia_restore_attributes)
          touch
          each_counter_cached_associations do |association|
            if send(association.reflection.name)
              association.increment_counters
            end
          end
          @_disable_counter_cache = false
        end
        restore_associated_records(recovery_window_range) if opts[:recursive]
      end
    end

    self
  end
  alias :restore :restore!

  def get_recovery_window_range(opts)
    return opts[:recovery_window_range] if opts[:recovery_window_range]
    return unless opts[:recovery_window]
    (deletion_time - opts[:recovery_window]..deletion_time + opts[:recovery_window])
  end

  def within_recovery_window?(recovery_window_range)
    return true unless recovery_window_range
    recovery_window_range.cover?(deletion_time)
  end

  def paranoia_destroyed?
    paranoia_column_value != paranoia_sentinel_value
  end
  alias :deleted? :paranoia_destroyed?

  def paranoia_update_columns(attributes)
    attributes.keys.each do |key|
      send("#{key}_will_change!")
    end
    update_columns(attributes)
    changes_applied
  end

  def really_destroy!(update_destroy_attributes: true)
    with_transaction_returning_status do
      run_callbacks(:real_destroy) do
        @_disable_counter_cache = paranoia_destroyed?
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
              next association_data.with_deleted.find_each { |record|
                record.really_destroy!(update_destroy_attributes: update_destroy_attributes)
              }
            end
            association_data.really_destroy!(update_destroy_attributes: update_destroy_attributes)
          end
        end
        update_columns(paranoia_destroy_attributes) if update_destroy_attributes
        destroy_without_paranoia
      end
    end
  end

  private

  def counter_cache_disabled?
    defined?(@_disable_counter_cache) && @_disable_counter_cache
  end

  def counter_cached_association_names
    return [] if counter_cache_disabled?
    super
  end

  def each_counter_cached_associations
    return [] if counter_cache_disabled?

    if defined?(super)
      super
    else
      counter_cached_association_names.each do |name|
        yield association(name)
      end
    end
  end

  def paranoia_restore_attributes
    {
      paranoia_column => paranoia_sentinel_value
    }.merge(timestamp_attributes_with_current_time)
  end

  def paranoia_destroy_attributes
    {
      paranoia_column => current_time_from_proper_timezone
    }.merge(timestamp_attributes_with_current_time)
  end

  def timestamp_attributes_with_current_time
    timestamp_attributes_for_update_in_model.each_with_object({}) { |attr,hash| hash[attr] = current_time_from_proper_timezone }
  end

  def paranoia_find_has_one_target(association)
    association_foreign_key = association.options[:through].present? ? association.klass.primary_key : association.foreign_key
    association_find_conditions = { association_foreign_key => self.id }
    association_find_conditions[association.type] = self.class.name if association.type

    scope = association.klass.only_deleted.where(association_find_conditions)
    scope = scope.merge(association.scope) if association.scope
    scope.first
  end

  # restore associated records that have been soft deleted when
  # we called #destroy
  def restore_associated_records(recovery_window_range = nil)
    destroyed_associations = self.class.reflect_on_all_associations.select do |association|
      association.options[:dependent] == :destroy
    end

    destroyed_associations.each do |association|
      association_data = send(association.name)

      unless association_data.nil?
        if association_data.paranoid?
          if association.collection?
            association_data.only_deleted.each do |record|
              record.restore(:recursive => true, :recovery_window_range => recovery_window_range)
            end
          else
            association_data.restore(:recursive => true, :recovery_window_range => recovery_window_range)
          end
        end
      end

      if association_data.nil? && association.macro.to_s == "has_one"
        if association.klass.paranoid?
          paranoia_find_has_one_target(association)
            .try!(:restore, recursive: true, :recovery_window_range => recovery_window_range)
        end
      end
    end

    if ActiveRecord.version.to_s > '7'
      # Method deleted in https://github.com/rails/rails/commit/dd5886d00a2d5f31ccf504c391aad93deb014eb8
      @association_cache.clear if persisted? && destroyed_associations.present?
    else
      clear_association_cache if destroyed_associations.present?
    end
  end
end

ActiveSupport.on_load(:active_record) do
  class ActiveRecord::Base
    def self.acts_as_paranoid(options={})
      if included_modules.include?(Paranoia)
        puts "[WARN] #{self.name} is calling acts_as_paranoid more than once!"

        return
      end

      define_model_callbacks :restore, :real_destroy

      alias_method :really_destroyed?, :destroyed?
      alias_method :really_delete, :delete
      alias_method :destroy_without_paranoia, :destroy

      include Paranoia
      class_attribute :paranoia_column, :paranoia_sentinel_value

      self.paranoia_column = (options[:column] || :deleted_at).to_s
      self.paranoia_sentinel_value = options.fetch(:sentinel_value) { Paranoia.default_sentinel_value }
      def self.paranoia_scope
        where(paranoia_column => paranoia_sentinel_value)
      end
      class << self; alias_method :without_deleted, :paranoia_scope end

      unless options[:without_default_scope]
        default_scope { paranoia_scope }
      end

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

    def paranoia_column_value
      send(paranoia_column)
    end

    def paranoia_sentinel_value
      self.class.paranoia_sentinel_value
    end

    def deletion_time
      paranoia_column_value.acts_like?(:time) ? paranoia_column_value : deleted_at
    end
  end
end

require 'paranoia/rspec' if defined? RSpec

module ActiveRecord
  module Validations
    module UniquenessParanoiaValidator
      def build_relation(klass, *args)
        relation = super
        return relation unless klass.respond_to?(:paranoia_column)
        arel_paranoia_scope = klass.arel_table[klass.paranoia_column].eq(klass.paranoia_sentinel_value)
        if ActiveRecord::VERSION::STRING >= "5.0"
          relation.where(arel_paranoia_scope)
        else
          relation.and(arel_paranoia_scope)
        end
      end
    end

    class UniquenessValidator < ActiveModel::EachValidator
      prepend UniquenessParanoiaValidator
    end

    class AssociationNotSoftDestroyedValidator < ActiveModel::EachValidator
      def validate_each(record, attribute, value)
        # if association is soft destroyed, add an error
        if value.present? && value.paranoia_destroyed?
          record.errors.add(attribute, 'has been soft-deleted')
        end
      end
    end
  end
end
