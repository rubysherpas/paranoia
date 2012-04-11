module Paranoia
  def self.included(klazz)
    klazz.extend Query
  end

  module Query
    def paranoid? ; true ; end

    def only_deleted
      unscoped {
        where("deleted_at is not null")
      }
    end
  end

  def destroy
    run_callbacks(:destroy) { delete }
  end

  def delete    
    if persisted?
      self.deleted_at = Time.now
      self.class.update_all({ :deleted_at => deleted_at }, self.class.primary_key => id)
    end

    @destroyed = true
    freeze
  end
  
  def restore!
    if persisted?
      self.deleted_at = nil
      self.class.update_all({ :deleted_at => deleted_at }, self.class.primary_key => id)
    end
  end

  # Has this record been marked as deleted? 
  # This serves a different purpose than ActiveRecord#destroyed?, which checks 
  # if the record in memory has been marked as destroyed.
  def deleted?
    !self.deleted_at.nil?
  end
end

class ActiveRecord::Base
  def self.acts_as_paranoid
    alias_method :destroy!, :destroy
    alias_method :delete!,  :delete
    include Paranoia
    default_scope :conditions => { :deleted_at => nil }
  end

  def self.paranoid? ; false ; end
  def paranoid? ; self.class.paranoid? ; end
end
