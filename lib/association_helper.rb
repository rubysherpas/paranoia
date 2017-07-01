# frozen_string_literal: true
module AssociationHelper
  def self.included(klazz)
    klazz.extend QueryAssociations
  end

  module QueryAssociations
    private

    # This method generates an instance method with the name: associated_sym.to_s.pluralize.
    #
    # Example:
    #   class User < ActiveRecord::Base
    #     belongs_to :role
    #     collection_for_edit :role
    #   end
    #
    # If the class defines a scope with a custom name, then that can be passed in with the options hash with the key 'name_prefix'
    # like so:
    #   class Store < ActiveRecord::Base
    #     belongs_to :sales_person, class_name: User.to_s
    #     collection_for_edit :sales_person, nil, name_prefix: :salesmen
    #     collection_for_edit :sales_person, -> { User.salesmen }, name_prefix: :salesmen   # This is equivalent to the above
    #   end
    #
    # The method will evaluate the scope_block if specified to get all the values for the edit dropdown. If the scope_block is nil,
    # the method will try to deduce it from the association. Again, if there is a scope defined for the association class with the
    # same name as option 'name_prefix' or the pluralized version of the associated symbol, then that will be used to fetch all
    # records for the dropdown
    #
    def collection_for_edit(associated_sym, scope_block = nil, options = {})
      scope_name = derive_scope_name(associated_sym, options)
      method_name = "#{scope_name}_for_edit".to_sym
      return if instance_methods(false).include?(method_name)

      define_method method_name do
        all_records = case scope_block
                      when nil
                        association_class = self.class.reflect_on_association(associated_sym).class_name.constantize
                        association_class.respond_to?(scope_name) ? association_class.send(scope_name) : association_class.all
                      else
                        scope_block.call
                      end
        # TODO: This might be optimizable if we can push the inclusion into the db itself
        associated_model = send(associated_sym)
        associated_model.present? && associated_model.deleted? ? [associated_model] + all_records.to_a : all_records.to_a
      end
    end

    def derive_scope_name(associated_sym, options)
      (options[:name_prefix] || associated_sym.to_s.pluralize).to_s.to_sym
    end
  end
end
