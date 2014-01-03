require 'test/unit'
require 'active_record'
require File.expand_path(File.dirname(__FILE__) + '/../lib/paranoia')

DB_FILE = 'tmp/test_db'

FileUtils.mkdir_p File.dirname(DB_FILE)
FileUtils.rm_f DB_FILE

ActiveRecord::Base.establish_connection :adapter => 'sqlite3', :database => DB_FILE
ActiveRecord::Base.connection.execute 'CREATE TABLE parent_models (id INTEGER NOT NULL PRIMARY KEY, deleted_at DATETIME)'
ActiveRecord::Base.connection.execute 'CREATE TABLE paranoid_models (id INTEGER NOT NULL PRIMARY KEY, parent_model_id INTEGER, deleted_at DATETIME)'
ActiveRecord::Base.connection.execute 'CREATE TABLE featureful_models (id INTEGER NOT NULL PRIMARY KEY, deleted_at DATETIME, name VARCHAR(32))'
ActiveRecord::Base.connection.execute 'CREATE TABLE plain_models (id INTEGER NOT NULL PRIMARY KEY, deleted_at DATETIME)'
ActiveRecord::Base.connection.execute 'CREATE TABLE callback_models (id INTEGER NOT NULL PRIMARY KEY, deleted_at DATETIME)'
ActiveRecord::Base.connection.execute 'CREATE TABLE related_models (id INTEGER NOT NULL PRIMARY KEY, parent_model_id INTEGER NOT NULL, deleted_at DATETIME)'
ActiveRecord::Base.connection.execute 'CREATE TABLE employers (id INTEGER NOT NULL PRIMARY KEY, deleted_at DATETIME)'
ActiveRecord::Base.connection.execute 'CREATE TABLE employees (id INTEGER NOT NULL PRIMARY KEY, deleted_at DATETIME)'
ActiveRecord::Base.connection.execute 'CREATE TABLE jobs (id INTEGER NOT NULL PRIMARY KEY, employer_id INTEGER NOT NULL, employee_id INTEGER NOT NULL, deleted_at DATETIME)'
ActiveRecord::Base.connection.execute 'CREATE TABLE custom_column_models (id INTEGER NOT NULL PRIMARY KEY, destroyed_at DATETIME)'
ActiveRecord::Base.connection.execute 'CREATE TABLE non_paranoid_models (id INTEGER NOT NULL PRIMARY KEY, parent_model_id INTEGER)'

class ParanoiaTest < Test::Unit::TestCase
  def test_plain_model_class_is_not_paranoid
    assert_equal false, PlainModel.paranoid?
  end

  def test_paranoid_model_class_is_paranoid
    assert_equal true, ParanoidModel.paranoid?
  end

  def test_plain_models_are_not_paranoid
    assert_equal false, PlainModel.new.paranoid?
  end

  def test_paranoid_models_are_paranoid
    assert_equal true, ParanoidModel.new.paranoid?
  end

  def test_paranoid_models_to_param
    model = ParanoidModel.new
    model.save
    to_param = model.to_param

    model.destroy

    assert_not_equal nil, model.to_param
    assert_equal to_param, model.to_param
  end

  def test_destroy_behavior_for_plain_models
    model = PlainModel.new
    assert_equal 0, model.class.count
    model.save!
    assert_equal 1, model.class.count
    model.destroy

    assert_equal true, model.deleted_at.nil?

    assert_equal 0, model.class.count
    assert_equal 0, model.class.unscoped.count
  end

  # Anti-regression test for #81, which would've introduced a bug to break this test.
  def test_destroy_behavior_for_plain_models_callbacks
    model = CallbackModel.new
    model.save
    model.remove_called_variables     # clear called callback flags
    model.destroy

    assert_equal nil, model.instance_variable_get(:@update_callback_called)
    assert_equal nil, model.instance_variable_get(:@save_callback_called)
    assert_equal nil, model.instance_variable_get(:@validate_called)

    assert model.instance_variable_get(:@destroy_callback_called)
    assert model.instance_variable_get(:@after_destroy_callback_called)
    assert model.instance_variable_get(:@after_commit_callback_called)
  end


  def test_delete_behavior_for_plain_models_callbacks
    model = CallbackModel.new
    model.save
    model.remove_called_variables     # clear called callback flags
    model.delete

    assert_equal nil, model.instance_variable_get(:@update_callback_called)
    assert_equal nil, model.instance_variable_get(:@save_callback_called)
    assert_equal nil, model.instance_variable_get(:@validate_called)
    assert_equal nil, model.instance_variable_get(:@destroy_callback_called)
    assert_equal nil, model.instance_variable_get(:@after_destroy_callback_called)
    assert_equal nil, model.instance_variable_get(:@after_commit_callback_called)
  end

  def test_destroy_behavior_for_paranoid_models
    model = ParanoidModel.new
    assert_equal 0, model.class.count
    model.save!
    assert_equal 1, model.class.count
    model.destroy

    assert_equal false, model.deleted_at.nil?

    assert_equal 0, model.class.count
    assert_equal 1, model.class.unscoped.count
  end

  def test_scoping_behavior_for_paranoid_models
    ParanoidModel.unscoped.delete_all
    parent1 = ParentModel.create
    parent2 = ParentModel.create
    p1 = ParanoidModel.create(:parent_model => parent1)
    p2 = ParanoidModel.create(:parent_model => parent2)
    p1.destroy
    p2.destroy
    assert_equal 0, parent1.paranoid_models.count
    assert_equal 1, parent1.paranoid_models.only_deleted.count
    assert_equal 1, parent1.paranoid_models.deleted.count
    p3 = ParanoidModel.create(:parent_model => parent1)
    assert_equal 2, parent1.paranoid_models.with_deleted.count
    assert_equal [p1, p3], parent1.paranoid_models.with_deleted
  end

  def test_destroy_behavior_for_custom_column_models
    model = CustomColumnModel.new
    assert_equal 0, model.class.count
    model.save!
    assert_nil model.destroyed_at
    assert_equal 1, model.class.count
    model.destroy

    assert_equal false, model.destroyed_at.nil?
    assert model.destroyed?

    assert_equal 0, model.class.count
    assert_equal 1, model.class.unscoped.count
    assert_equal 1, model.class.only_deleted.count
    assert_equal 1, model.class.deleted.count
  end

  def test_destroy_behavior_for_featureful_paranoid_models
    model = get_featureful_model
    assert_equal 0, model.class.count
    model.save!
    assert_equal 1, model.class.count
    model.destroy

    assert_equal false, model.deleted_at.nil?

    assert_equal 0, model.class.count
    assert_equal 1, model.class.unscoped.count
  end

  # Regression test for #24
  def test_chaining_for_paranoid_models
    scope = FeaturefulModel.where(:name => 'foo').only_deleted
    assert_equal 'foo', scope.where_values_hash['name']
    assert_equal 2, scope.where_values.count
  end

  def test_only_destroyed_scope_for_paranoid_models
    model = ParanoidModel.new
    model.save
    model.destroy
    model2 = ParanoidModel.new
    model2.save

    assert_equal model, ParanoidModel.only_deleted.last
    assert_equal false, ParanoidModel.only_deleted.include?(model2)
    assert_equal false, ParanoidModel.deleted.include?(model2)
  end

  def test_default_scope_for_has_many_relationships
    parent = ParentModel.create
    assert_equal 0, parent.related_models.count

    child = parent.related_models.create
    assert_equal 1, parent.related_models.count

    child.destroy
    assert_equal false, child.deleted_at.nil?

    assert_equal 0, parent.related_models.count
    assert_equal 1, parent.related_models.unscoped.count
  end

  def test_default_scope_for_has_many_through_relationships
    employer = Employer.create
    employee = Employee.create
    assert_equal 0, employer.jobs.count
    assert_equal 0, employer.employees.count
    assert_equal 0, employee.jobs.count
    assert_equal 0, employee.employers.count

    job = Job.create :employer => employer, :employee => employee
    assert_equal 1, employer.jobs.count
    assert_equal 1, employer.employees.count
    assert_equal 1, employee.jobs.count
    assert_equal 1, employee.employers.count

    employee2 = Employee.create
    job2 = Job.create :employer => employer, :employee => employee2
    employee2.destroy
    assert_equal 2, employer.jobs.count
    assert_equal 1, employer.employees.count

    job.destroy
    assert_equal 1, employer.jobs.count
    assert_equal 0, employer.employees.count
    assert_equal 0, employee.jobs.count
    assert_equal 0, employee.employers.count
  end

  def test_delete_behavior_for_callbacks
    model = CallbackModel.new
    model.save
    model.delete
    assert_equal nil, model.instance_variable_get(:@destroy_callback_called)
  end

  def test_destroy_behavior_for_callbacks
    model = CallbackModel.new
    model.save
    model.destroy
    assert model.instance_variable_get(:@destroy_callback_called)
  end

  def test_restore
    model = ParanoidModel.new
    model.save
    id = model.id
    model.destroy

    assert model.destroyed?

    model = ParanoidModel.only_deleted.find(id)
    model.restore!
    model.reload

    assert_equal false, model.destroyed?
  end

  # Regression test for #92
  def test_destroy_twice
    model = ParanoidModel.new
    model.save
    model.destroy
    model.destroy

    assert_equal 1, ParanoidModel.unscoped.where(id: model.id).count
  end

  def test_restore_behavior_for_callbacks
    model = CallbackModel.new
    model.save
    id = model.id
    model.destroy

    assert model.destroyed?

    model = CallbackModel.only_deleted.find(id)
    model.restore!
    model.reload

    assert model.instance_variable_get(:@restore_callback_called)
  end

  def test_real_destroy
    model = ParanoidModel.new
    model.save
    model.destroy!

    assert_equal 0, ParanoidModel.unscoped.where(id: model.id).count
  end

  def test_real_delete
    model = ParanoidModel.new
    model.save
    model.delete!
    assert_equal 0, ParanoidModel.unscoped.where(id: model.id).count
  end

  def test_multiple_restore
    a = ParanoidModel.new
    a.save
    a_id = a.id
    a.destroy

    b = ParanoidModel.new
    b.save
    b_id = b.id
    b.destroy

    c = ParanoidModel.new
    c.save
    c_id = c.id
    c.destroy

    ParanoidModel.restore([a_id, c_id])

    a.reload
    b.reload
    c.reload

    refute a.destroyed?
    assert b.destroyed?
    refute c.destroyed?
  end

  def test_restore_with_associations
    parent = ParentModel.create
    first_child = parent.very_related_models.create
    second_child = parent.non_paranoid_models.create

    parent.destroy
    assert_equal false, parent.deleted_at.nil?
    assert_equal false, first_child.reload.deleted_at.nil?
    assert_equal true, second_child.destroyed?

    parent.restore!
    assert_equal true, parent.deleted_at.nil?
    assert_equal false, first_child.reload.deleted_at.nil?
    assert_equal true, second_child.destroyed?

    parent.destroy
    parent.restore(:recursive => true)
    assert_equal true, parent.deleted_at.nil?
    assert_equal true, first_child.reload.deleted_at.nil?
    assert_equal true, second_child.destroyed?

    parent.destroy
    ParentModel.restore(parent.id, :recursive => true)
    assert_equal true, parent.reload.deleted_at.nil?
    assert_equal true, first_child.reload.deleted_at.nil?
    assert_equal true, second_child.destroyed?
  end

  def test_observers_notified
    a = ParanoidModelWithObservers.create
    a.destroy
    a.restore!

    assert a.observers_notified.select {|args| args == [:before_restore, a]}
    assert a.observers_notified.select {|args| args == [:after_restore, a]}
  end

  def test_observers_not_notified_if_not_supported
    a = ParanoidModelWithObservers.create
    a.destroy
    a.restore!
    # essentially, we're just ensuring that this doesn't crash
  end

  private
  def get_featureful_model
    FeaturefulModel.new(:name => 'not empty')
  end
end

# Helper classes

class ParentModel < ActiveRecord::Base
  has_many :paranoid_models
end

class ParanoidModel < ActiveRecord::Base
  belongs_to :parent_model
  acts_as_paranoid
end

class FeaturefulModel < ActiveRecord::Base
  acts_as_paranoid
  validates :name, :presence => true, :uniqueness => true
end

class PlainModel < ActiveRecord::Base
end

class CallbackModel < ActiveRecord::Base
  acts_as_paranoid
  before_destroy {|model| model.instance_variable_set :@destroy_callback_called, true }
  before_restore {|model| model.instance_variable_set :@restore_callback_called, true }
  before_update  {|model| model.instance_variable_set :@update_callback_called, true }
  before_save    {|model| model.instance_variable_set :@save_callback_called, true}

  after_destroy  {|model| model.instance_variable_set :@after_destroy_callback_called, true }
  after_commit   {|model| model.instance_variable_set :@after_commit_callback_called, true }

  validate       {|model| model.instance_variable_set :@validate_called, true }

  def remove_called_variables
    instance_variables.each {|name| (name.to_s.end_with?('_called')) ? remove_instance_variable(name) : nil}
  end
end

class ParentModel < ActiveRecord::Base
  acts_as_paranoid
  has_many :related_models
  has_many :very_related_models, :class_name => 'RelatedModel', dependent: :destroy
  has_many :non_paranoid_models, dependent: :destroy
end

class RelatedModel < ActiveRecord::Base
  acts_as_paranoid
  belongs_to :parent_model
end

class Employer < ActiveRecord::Base
  acts_as_paranoid
  has_many :jobs
  has_many :employees, :through => :jobs
end

class Employee < ActiveRecord::Base
  acts_as_paranoid
  has_many :jobs
  has_many :employers, :through => :jobs
end

class Job < ActiveRecord::Base
  acts_as_paranoid
  belongs_to :employer
  belongs_to :employee
end

class CustomColumnModel < ActiveRecord::Base
  acts_as_paranoid column: :destroyed_at
end

class NonParanoidModel < ActiveRecord::Base
end

class ParanoidModelWithObservers < ParanoidModel
  def observers_notified
    @observers_notified ||= []
  end

  def self.notify_observer(*args)
    observers_notified << args
  end
end

class ParanoidModelWithoutObservers < ParanoidModel
  self.class.send(remove_method :notify_observers) if method_defined?(:notify_observers)
end
