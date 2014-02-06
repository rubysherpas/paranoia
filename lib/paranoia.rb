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
    callbacks_result = run_callbacks(:destroy) do
      # don't update paranioa column unless it hasn't already been destroyed
      touch_paranoia_column(true) unless destroyed?
    end
    callbacks_result ? self : false
  end

  def delete
    return if new_record?
    touch_paranoia_column(false)
  end

  def restore!(opts = {})
    ActiveRecord::Base.transaction do
      run_callbacks(:restore) do
        deleted_at = send(paranoia_column)
        update_column paranoia_column, nil
        if opts[:recursive]
          recovery_window_range = if opts[:dependent_recovery_window]
                              # opts[:dependent_recovery_window] expected to be a timespan in seconds
                              # e.g. 2.minutes
                              #
                              # now create the range
                              (deleted_at-opts[:dependent_recovery_window]..deleted_at+opts[:dependent_recovery_window])
                            else
                              opts[:recovery_window_range]
                            end
          
          restore_associated_records(recovery_window_range)
        end
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
    if with_transaction
      with_transaction_returning_status { touch(paranoia_column) }
    else
      touch(paranoia_column)
    end
  end

  # restore associated records that have been soft deleted when
  # we called #destroy
  def restore_associated_records(recovery_window_range = nil)
    destroyed_associations = self.class.reflect_on_all_associations.select do |association|
      association.options[:dependent] == :destroy
    end

    destroyed_associations.each do |association|
      association = send(association.name)

      if association.paranoid?
        association.only_deleted.select do |record|
          recovery_window_range.nil? || recovery_window_range.cover?(record.send(record.paranoia_column))
        end.each do |record|
          record.restore(:recursive => true, :recovery_window_range => recovery_window_range)
        end
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
