module Paranoia
  def self.included(klazz)
    klazz.extend Query
  end

  module Query
    def paranoid? ; true ; end
  end

  def destroy
    _run_destroy_callbacks
    self[:deleted_at] ||= Time.now
    # If the instance has already been persisted, then we need to re-save it to flag it as
    # destroyed / deleted.  We don't require validation in case it causes the updated to fail.
    save(:validate => false) if persisted?
    freeze
  end
  alias :delete :destroy

  def destroyed?
    !self[:deleted_at].nil?
  end
  alias :deleted? :destroyed?
end

class ActiveRecord::Base
  def self.acts_as_paranoid
    self.send(:include, Paranoia)
    default_scope :conditions => { :deleted_at => nil }
  end

  def self.paranoid? ; false ; end
  def paranoid? ; self.class.paranoid? ; end
end
