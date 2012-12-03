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

    protected

    # Public: hard-destroy these dependencies with callbacks after this
    # resource is destroyed.  (Note: this will not be fired if the resource is
    # deleted, as callbacks are not called.)
    def self.hard_destroy_dependencies(*dependencies)
      hard_remove_dependencies(:destroy!, dependencies)
    end

    # Public: hard-delete these dependencies without callbacks after this
    # resource is destroyed.  (Note: this will not be fired if the resource is
    # deleted, as callbacks are not called.)
    def self.hard_delete_dependencies(*dependencies)
      hard_remove_dependencies(:delete!, dependencies)
    end

    # Internal: Relations that have been marked for hard-destroy (with callbacks).
    def self.hard_destroy_relations
      @_hard_destroy_relations ||= []
    end

    # Internal: Relations that have been marked for hard-delete (without callbacks).
    def self.hard_delete_relations
      @_hard_delete_relations ||= []
    end

    private

    # Internal: register a dependency to be hard-removed after this resource is
    # destroyed.
    #
    # action - either destroy! or :delete!
    # dependencies - a list of relations
    #
    # Raises ArgumentError if action is invalid
    # Raises ArgumentError if the dependency can't be found
    # Raises ArgumentError if the dependency isn't belongs_to, has_one, or has_many
    def self.hard_remove_dependencies(action, dependencies = [])
      unless [:destroy!, :delete!].include?(action)
        raise ArgumentError, "Invalid action, must be delete! or destroy!"
      end

      dependencies.each do |name|
        name = name.to_sym
        key, details = self.reflections.detect {|k, v| k == name}
        if key
          if [:has_many, :belongs_to, :has_one].include?(details.macro)
            if action == :destroy!
              hard_destroy_relations << name
            elsif action == :delete!
              hard_delete_relations << name
            end

            # Register the hard-remove callback if it hasn't been registered
            unless @_hard_remove_registered
              after_destroy :hard_remove_relations
              @_hard_remove_registered = true
            end
          else
            raise ArgumentError, "Unable to hard-remove dependencies of type #{type}"
          end
        else
          raise ArgumentError, "Unable to find dependency #{name}!"
        end
      end
    end

    # Internal: actually hard-remove the relations after this resource has been
    # removed.  Note that, unlike Rails' own dependency management, this here
    # only works if this object is removed with callbacks (#destroy/#destroy!).
    # To remove dependent relationships using #delete, you'd need to implement
    # a "self-destruct" mechanism that could call hard_remove_relations first
    # and then self.delete (or self.delete!).
    def hard_remove_relations
      self.class.hard_destroy_relations.each do |name|
        if reflections[name].macro == :has_many
          puts "Destroying #{self.send(name).to_a.inspect}"
          self.send(name).map(&:destroy!)
        elsif object = self.send(name)
          object.destroy!
        end
      end

      self.class.hard_delete_relations.each do |name|
        if reflections[name].macro == :has_many
          self.send(name).delete_all
        elsif object = self.send(name)
          object.delete!
        end
      end
    end
  end
end