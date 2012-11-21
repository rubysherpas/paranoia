module ActiveRecord
  # Update associations to allow hard-deleting dependencies.
  module Associations
    # properly set up class heirarchy
    class Association; end
    class SingularAssociation < Association; end
    class CollectionAssociation < Association; end

    # from rails/activerecord/lib/active_record/associations/has_one_association.rb
    class HasOneAssociation < SingularAssociation #:nodoc:
      def delete(method = options[:dependent])
        if load_target
          case method
          when :delete
            target.delete
          when :destroy
            target.destroy
          when :delete!
            target.delete!
          when :destroy!
            target.destroy!
          when :nullify
            target.update_column(reflection.foreign_key, nil)
          end
        end
      end
    end

    # from rails/activerecord/lib/active_record/associations/has_many_association.rb
    class HasManyAssociation < CollectionAssociation
      # Deletes the records according to the <tt>:dependent</tt> option.
      def delete_records(records, method)
        if method == :destroy || method == :destroy!
          records.each { |r| r.send(method) }
          update_counter(-records.length) unless inverse_updates_counter_cache?
        else
          keys  = records.map { |r| r[reflection.association_primary_key] }
          scope = scoped.where(reflection.association_primary_key => keys)

          if method == :delete_all
            update_counter(-scope.delete_all)
          else
            update_counter(-scope.update_all(reflection.foreign_key => nil))
          end
        end
      end
    end

    # Allow our new options in
    module Builder
      # properly set up class heirarchy
      class Association; end
      class SingularAssociation < Association; end
      class CollectionAssociation < Association; end

      class HasOne < SingularAssociation
        # Rails 4
        def valid_dependent_options
          [
           :destroy, :delete, :nullify, :restrict, :restrict_with_error, :restrict_with_exception,
           :destroy!, :delete!
          ]
        end

        # Rails 3.2.x
        def configure_dependency
          if options[:dependent]
            unless valid_dependent_options.include?(options[:dependent])
              raise ArgumentError, "The :dependent option expects one of " \
                "#{valid_dependent_options.join(", ")} (received #{options[:dependent].inspect})"
            end

            # map the ! methods to their non-! counterparts
            method_name = options[:dependent].to_s.gsub(/\!/, "")
            send("define_#{method_name}_dependency_method")
            model.before_destroy dependency_method_name
          end
        end

        def dependency_method_name
          method_name = options[:dependent].to_s.gsub(/\!/, "")
          "has_one_dependent_#{method_name}_for_#{name}"
        end
      end

      class HasMany < CollectionAssociation
        def valid_dependent_options
          [
            :destroy, :delete_all, :nullify, :restrict, :restrict_with_error, :restrict_with_exception,
            :destroy!
          ]
        end

        def configure_dependency
          if options[:dependent]
            unless valid_dependent_options.include?(options[:dependent])
              raise ArgumentError, "The :dependent option expects one of " \
                "#{valid_dependent_options.join(", ")} (received #{options[:dependent].inspect})"
            end

            method_name = options[:dependent].to_s.gsub(/\!/, "")
            send("define_#{method_name}_dependency_method")
            model.before_destroy dependency_method_name
          end
        end
      end
    end
  end
end