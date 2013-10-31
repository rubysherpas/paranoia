module Paranoia
  def self.included(klazz)
    klazz.extend Query
    klazz.extend Callbacks
  end

  module Query
    def paranoid?
      true
    end


    def with_deleted
      scoped.tap { |x| x.default_scoped = false }
    end

    def only_deleted
      with_deleted.where("#{self.table_name}.#{paranoia_column} IS NOT NULL")
    end
    alias :deleted :only_deleted

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
    destroyed? ? destroy! : update_attrs_without_valid(paranoia_column => Time.now)
  end

  def restore!
    run_callbacks(:restore) { update_attrs_without_valid(paranoia_column => nil) }
  end
  alias :restore :restore!

  def destroyed?
    !!send(paranoia_column)
  end

  alias :deleted? :destroyed?

  private

  # update attributes without validation
  # @param attributes [Hash] attributes
  def update_attrs_without_valid(attributes)
    assign_attributes(attributes)
    save(:validate => false)
  end

end

class ActiveRecord::Base
  def self.acts_as_paranoid(options={})
    alias :destroy! :destroy
    alias :delete! :delete
    include Paranoia
    class_attribute :paranoia_column

    self.paranoia_column = options[:column] || :deleted_at
    default_scope { where(self.quoted_table_name + ".#{paranoia_column} IS NULL") }
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

  private

  def paranoia_column
    self.class.paranoia_column
  end
end
