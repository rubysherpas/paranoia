module Paranoia
  def deleted?
    !!self["deleted_at"]
  end
  
  def destroy
    self["deleted_at"] = Time.now
    self.save
    _run_destroy_callbacks
  end
  
  alias_method :delete, :destroy
    
end

class ActiveRecord::Base
  def self.acts_as_paranoid
    self.send(:include, Paranoia)
    default_scope :conditions => { :deleted_at => nil }
  end
end
  