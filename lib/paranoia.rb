module Paranoia
  def self.included(klazz)
    klazz.extend Query
    klazz.extend Callbacks
  end

  module Query
    def paranoid? ; true ; end

    def only_deleted
      all.tap { |x| x.default_scoped = false }.where.not(deleted_at: nil)
    end

    def with_deleted
      all.tap { |x| x.default_scoped = false }
    end

    def restore(id)
      if id.is_a?(Array)
        id.map { |one_id| restore(one_id) }
      else
        only_deleted.find(id).restore!
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
    run_callbacks(:destroy) { delete }
  end

  def delete
    return if new_record?
    destroyed? ? destroy! : update_column(:deleted_at, Time.now)
  end

  def restore!
    run_callbacks(:restore) { update_column :deleted_at, nil }
  end

  def destroyed?
    !self.deleted_at.nil?
  end
  alias :deleted? :destroyed?
end

class ActiveRecord::Base
  def self.acts_as_paranoid
    alias :destroy! :destroy
    alias :delete!  :delete
    include Paranoia
    default_scope { where(:deleted_at => nil) }
  end

  def self.paranoid? ; false ; end
  def paranoid? ; self.class.paranoid? ; end

  # Override the persisted method to allow for the paranoia gem.
  # If a paranoid record is selected, then we only want to check
  # if it's a new record, not if it is "destroyed".
  def persisted?
    paranoid? ? !new_record? : super
  end
end
