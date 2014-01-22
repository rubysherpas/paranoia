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
    with_transaction_returning_status do
      run_callbacks(:destroy) { touch(paranoia_column) }
    end
  end

  def delete
    return if new_record?
    touch(paranoia_column)
  end

  def restore!(opts = {})
    ActiveRecord::Base.transaction do
      run_callbacks(:restore) do
        update_column paranoia_column, nil
        update_column paranoia_dependent_column, false if respond_to?(paranoia_dependent_column)
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
  # set dependent delete flg to associations.
  # @note This method will be called when run before_destroy event.
  def set_dependent_associations
    each_paranoid_associations do |resource, resource_class, collection|
      next unless resource_class.column_names.include?(paranoia_dependent_column.to_s)

      if collection
        resource.where(deleted_at: nil).update_all(paranoia_dependent_column => true)
      else
        resource.update_column(paranoia_dependent_column, true)
      end
    end
  end

  # exec block with each paranoid association.
  # @param &block [Proc{|resource, resource_class, collection_flg| .. }] exec block.
  def each_paranoid_associations(&block)
    self.class.reflect_on_all_associations.each do |association|
      next unless association.options[:dependent] == :destroy
      next unless association.klass.paranoid?

      resource = association.klass.unscoped do
        if association.collection?
          # Must call `order`, because rails4.0.2 and 3.2.3 have a bug. It disables `unscoped`.
          send(association.name).order(:id)
        else
          send(association.name)
        end
      end

      next unless resource.present?
      block.call(resource, association.klass, association.collection?)
    end
  end

  # restore associated records that have been soft deleted when
  # we called #destroy
  def restore_associated_records
    each_paranoid_associations do |resource, resource_class, collection|
      resources = (collection) ? resource : [resource]

      resources.each do |record|
        next unless record.destroyed?
        next if record.respond_to?(paranoia_dependent_column) and !record.send(paranoia_dependent_column)
        record.restore(:recursive => true)
      end
    end
  end
end

class ActiveRecord::Base
  def self.acts_as_paranoid(options={})
    alias :ar_destroy :destroy
    alias :destroy! :ar_destroy
    alias :delete! :delete
    include Paranoia
    class_attribute :paranoia_column, :paranoia_dependent_column

    self.paranoia_column = options[:column] || :deleted_at
    self.paranoia_dependent_column = options[:dependent_column] || :dependent_delete
    default_scope { where(self.quoted_table_name + ".#{paranoia_column} IS NULL") }

    before_restore {
      self.class.notify_observers(:before_restore, self) if self.class.respond_to?(:notify_observers)
    }
    after_restore {
      self.class.notify_observers(:after_restore, self) if self.class.respond_to?(:notify_observers)
    }

    before_destroy :set_dependent_associations
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

  def paranoia_dependent_column
    self.class.paranoia_dependent_column
  end
end
