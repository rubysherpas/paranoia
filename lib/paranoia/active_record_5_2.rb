module HandleParanoiaDestroyedInBelongsToAssociation
  def handle_dependency
    return unless load_target

    case options[:dependent]
    when :destroy
      @_destroy_callback_already_called ||= false
      return if @_destroy_callback_already_called
      @_destroy_callback_already_called = true
      target.destroy
      if target.respond_to?(:paranoia_destroyed?)
        raise ActiveRecord::Rollback unless target.paranoia_destroyed?
      else
        raise ActiveRecord::Rollback unless target.destroyed?
      end
    else
      target.send(options[:dependent])
    end
  end
end

module HandleParanoiaDestroyedInHasOneAssociation
  def delete(method = options[:dependent])
    if load_target
      case method
      when :delete
        target.delete
      when :destroy
        @_destroy_callback_already_called ||= false
        return if @_destroy_callback_already_called
        target.destroyed_by_association = reflection
        @_destroy_callback_already_called = true
        target.destroy
        if target.respond_to?(:paranoia_destroyed?)
          throw(:abort) unless target.paranoia_destroyed?
        else
          throw(:abort) unless target.destroyed?
        end
      when :nullify
        target.update_columns(reflection.foreign_key => nil) if target.persisted?
      end
    end
  end
end

ActiveRecord::Associations::BelongsToAssociation.prepend HandleParanoiaDestroyedInBelongsToAssociation
ActiveRecord::Associations::HasOneAssociation.prepend HandleParanoiaDestroyedInHasOneAssociation
