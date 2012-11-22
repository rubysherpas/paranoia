# Paranoia

Paranoia is a re-implementation of [acts\_as\_paranoid](http://github.com/technoweenie/acts_as_paranoid) for Rails 3, using much, much, much less code.

You would use either plugin / gem if you wished that when you called `destroy` on an Active Record object that it didn't actually destroy it, but just "hid" the record. Paranoia does this by setting a `deleted_at` field to the current time when you `destroy` a record, and hides it by scoping all queries on your model to only include records which do not have a `deleted_at` field.

## Installation & Usage

Put this in your Gemfile:

```ruby
gem 'paranoia'
```

Then run `bundle`. Done.

Updating is as simple as `bundle update paranoia`.

#### Rails 3

In your _Gemfile_:

```ruby
gem 'paranoia'
```

Then run:

```shell
bundle install
```

#### Rails 2:

In your _config/environment.rb_:

```ruby
config.gem 'paranoia'
```

Then run:

```shell
rake gems:install
```

#### Run your migrations for the desired models

```ruby
class AddDeletedAtToClient < ActiveRecord::Migration
  def self.up
    add_column :clients, :deleted_at, :datetime
  end

  def self.down
    remove_column :clients, :deleted_at
  end
end
```

### Usage

#### In your model:

```ruby
class Client < ActiveRecord::Base
  acts_as_paranoid

  ...
end
```

Hey presto, it's there!

If you want a method to be called on destroy, simply provide a _before\_destroy_ callback:

```ruby
class Client < ActiveRecord::Base
  acts_as_paranoid

  before_destroy :some_method

  def some_method
    # do stuff
  end

  ...
end
```

You can replace the older acts_as_paranoid methods as follows:

```ruby
find_with_deleted(:all)       # => with_deleted
find_with_deleted(:first)     # => with_deleted.first
find_with_deleted(id)         # => with_deleted.find(id)

find_only_deleted(:all)       # => only_deleted
find_only_deleted(:first)     # => only_deleted.first
find_only_deleted(id)         # => only_deleted.find(id)
```

Paranoia also provides a mechanism for cascading hard-deletes to paranoid
resources -- for instance, if you want to hard-delete users and all associated
resources when they delete their account:

```ruby
# By default, associations with `dependent: :destroy` or `dependent: :delete`
# will soft-delete associated records (with or without callbacks, respectively).
# If you want to hard-delete paranoid dependencies, don't use AR's dependent
# option; instead, use these methods:
hard_destroy_dependencies :widgets, :operator # hard-destroys with callbacks
hard_delete_dependencies :widgets # hard-deletes dependencies
# Both methods can take any mixture of :has_many, :has_one, and :belongs_to.
```

Note that unlike ActiveRecord's built-in dependency management, this will only
fire when objects are destroyed, not deleted, since it works via an
after_destroy callback.  (Make sure to register any callbacks that depend on
children before the hard_destroy_dependencies.)

Also note that hard-destroys will trigger callbacks on child objects, but
hard-deletions won't (just like AR).  That said, if you hard-delete a paranoid object that has
a traditional `dependent: destroy` relationship with its own child, the
grandchild will be soft-deleted (if paranoid).  In this case, you should add a
`:through` relationship to the grandchild in the original object, and add it to
the hard-remove.  (The order of deletions and hence of callbacks being executed
depends on the order you define them.)

## License

This gem is released under the MIT license.