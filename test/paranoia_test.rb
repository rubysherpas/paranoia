require 'test/unit'
require 'active_record'
require File.expand_path(File.dirname(__FILE__) + "/../lib/paranoia")

DB_FILE = 'tmp/test_db'

FileUtils.mkdir_p File.dirname(DB_FILE)
FileUtils.rm_f DB_FILE

ActiveRecord::Base.establish_connection :adapter => 'sqlite3', :database => DB_FILE
ActiveRecord::Base.connection.execute 'CREATE TABLE paranoid_models (id INTEGER NOT NULL PRIMARY KEY, deleted_at DATETIME)'
ActiveRecord::Base.connection.execute 'CREATE TABLE featureful_models (id INTEGER NOT NULL PRIMARY KEY, deleted_at DATETIME, name VARCHAR(32))'
ActiveRecord::Base.connection.execute 'CREATE TABLE plain_models (id INTEGER NOT NULL PRIMARY KEY, deleted_at DATETIME)'
ActiveRecord::Base.connection.execute 'CREATE TABLE callback_models (id INTEGER NOT NULL PRIMARY KEY, deleted_at DATETIME)'

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

  def test_destroy_behavior_for_plain_models
    model = PlainModel.new
    assert_equal 0, model.class.count
    model.save!
    assert_equal 1, model.class.count
    model.destroy

    assert_equal true, model.deleted_at.nil?
    assert model.destroyed?
    assert model.frozen?
    assert !model.respond_to?(:deleted?)

    assert_equal 0, model.class.count
    assert_equal 0, model.class.unscoped.count
  end

  def test_destroy_behavior_for_paranoid_models
    model = ParanoidModel.new
    assert_equal 0, model.class.count
    model.save!
    assert_equal 1, model.class.count
    model.destroy

    assert_equal false, model.deleted_at.nil?
    assert model.destroyed?
    assert model.frozen?
    assert model.deleted?

    assert_equal 0, model.class.count
    assert_equal 1, model.class.unscoped.count

  end

  def test_destroy_behavior_for_featureful_paranoid_models
    model = get_featureful_model
    assert_equal 0, model.class.count
    model.save!
    assert_equal 1, model.class.count
    model.destroy

    assert_equal false, model.deleted_at.nil?
    assert model.destroyed?
    assert model.frozen?
    assert model.deleted?

    assert_equal 0, model.class.count
    assert_equal 1, model.class.unscoped.count
  end

  def test_only_destroyed_scope_for_paranoid_models
    model = ParanoidModel.new
    model.save
    model.destroy
    model2 = ParanoidModel.new
    model2.save

    assert_equal model, ParanoidModel.only_deleted.last
    assert_equal false, ParanoidModel.only_deleted.include?(model2)
  end
  
  def test_delete_behavior_for_callbacks
    model = CallbackModel.new
    model.save
    model.delete
    assert_equal nil, model.instance_variable_get(:@before_update_callback_called)
    assert_equal nil, model.instance_variable_get(:@before_destroy_callback_called)
  end
  
  def test_destroy_behavior_for_callbacks
    model = CallbackModel.new
    model.save
    model.destroy
    assert_equal nil, model.instance_variable_get(:@before_update_callback_called)
    assert model.instance_variable_get(:@before_destroy_callback_called)
  end
  
  def test_restore
    model = ParanoidModel.new
    model.save
    id = model.id
    model.destroy
    
    assert model.deleted?
    assert model.destroyed?
    
    model = ParanoidModel.only_deleted.find(id)
    model.restore!
    
    assert_equal false, model.deleted?
    assert_equal false, model.destroyed?
  end
  
  def test_real_destroy
    puts "Rails.version: #{ActiveRecord::VERSION::STRING}"
    model = ParanoidModel.new
    model.save
    model.destroy!
    
    assert_equal false, ParanoidModel.unscoped.exists?(model.id)
  end
  
  def test_real_delete
    model = ParanoidModel.new
    model.save
    model.delete!
    
    assert_equal false, ParanoidModel.unscoped.exists?(model.id)
  end

  private
  def get_featureful_model
    FeaturefulModel.new(:name => "not empty")
  end
end

# Helper classes

class ParanoidModel < ActiveRecord::Base
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
  before_update do |model| 
    model.instance_variable_set :@before_update_callback_called, true
  end
  before_destroy do |model|
    model.instance_variable_set :@before_destroy_callback_called, true
  end
end
