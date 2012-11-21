module ActiveRecord
  class Base
    def self.acts_as_paranoid
      alias_method :destroy!, :destroy
      alias_method :delete!,  :delete
      include Paranoia
      default_scope :conditions => { :deleted_at => nil }
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

  require 'paranoia/active_record_associations'
end