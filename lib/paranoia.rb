module Paranoia
  def self.included(klazz)
    klazz.extend Query
  end

  module Query
    def paranoid?
      true
    end

    def only_deleted
      scoped.tap { |x| x.default_scoped = false }.where("#{self.table_name}.deleted_at IS NOT NULL")
    end
    alias :deleted :only_deleted

    def with_deleted
      scoped.tap { |x| x.default_scoped = false }
    end

    def restore(id)
      if id.is_a?(Array)
        id.map { |one_id| restore(one_id) }
      else
        only_deleted.find(id).restore!
      end
    end
  end

  def destroy
    run_callbacks(:destroy) { delete }
  end

  def delete
    return if new_record? or destroyed?
    update_attribute_or_column :deleted_at, Time.now
  end

  def restore!
    update_attribute_or_column :deleted_at, nil
  end
  alias :restore :restore!

  def destroyed?
    !self.deleted_at.nil?
  end

  alias :deleted? :destroyed?

  private

  # Rails 3.1 adds update_column. Rails > 3.2.6 deprecates update_attribute, gone in Rails 4.
  def update_attribute_or_column(*args)
    respond_to?(:update_column) ? update_column(*args) : update_attribute(*args)
  end
end

class ActiveRecord::Base
  def self.acts_as_paranoid
    alias :destroy! :destroy
    alias :delete! :delete
    include Paranoia
    default_scope { where(deleted_at: nil) }
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
end
