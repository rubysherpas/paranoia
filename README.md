# Paranoia

Paranoia is a re-implementation of [acts\_as\_paranoid](http://github.com/technoweenie/acts_as_paranoid) for Rails 3, using much, much, much less code.

You would use either plugin / gem if you wished that when you called `destroy` on an Active Record object that it didn't actually destroy it, but just *hide* the record. Paranoia does this by setting a `deleted_at` field to the current time when you `destroy` a record, and hides it by scoping all queries on your model to only include records which do not have a `deleted_at` field.

If you wish to actually destroy an object you may call `really_destroy!`. **WARNING**: This will also *really destroy* all `dependent: destroy` records, so please aim this method away from face when using.**

If a record has `has_many` associations defined AND those associations have `dependent: :destroy` set on them, then they will also be soft-deleted if `acts_as_paranoid` is set,  otherwise the normal destroy will be called.

## Installation & Usage

For Rails 3, please use version 1 of Paranoia:

``` ruby
gem "paranoia", "~> 1.0"
```

For Rails 4, please use version 2 of Paranoia:

``` ruby
gem "paranoia", "~> 2.0"
```

Of course you can install this from GitHub as well:

``` ruby
gem "paranoia", :github => "radar/paranoia", :branch => "master"
# or
gem "paranoia", :github => "radar/paranoia", :branch => "rails4"
```

Then run:

``` shell
bundle install
```

Updating is as simple as `bundle update paranoia`.

#### Run your migrations for the desired models

Run:

``` shell
rails generate migration AddDeletedAtToClients deleted_at:datetime:index
```

and now you have a migration

``` ruby
class AddDeletedAtToClients < ActiveRecord::Migration
  def change
    add_column :clients, :deleted_at, :datetime
    add_index :clients, :deleted_at
  end
end
```

### Usage

#### In your model:

``` ruby
class Client < ActiveRecord::Base
  acts_as_paranoid

  # ...
end
```

Hey presto, it's there! Calling `destroy` will now set the `deleted_at` column:


``` ruby
>> client.deleted_at
# => nil
>> client.destroy
# => client
>> client.deleted_at
# => [current timestamp]
```

If you really want it gone *gone*, call `really_destroy!`:

``` ruby
>> client.deleted_at
# => nil
>> client.really_destroy!
# => client
```

If you want a method to be called on destroy, simply provide a `before_destroy` callback:

``` ruby
class Client < ActiveRecord::Base
  acts_as_paranoid

  before_destroy :some_method

  def some_method
    # do stuff
  end

  # ...
end
```

If you want to use a column other than `deleted_at`, you can pass it as an option:

``` ruby
class Client < ActiveRecord::Base
  acts_as_paranoid column: :destroyed_at

  ...
end
```

If you want to access soft-deleted associations, override the getter method:

``` ruby
def product
  Product.unscoped { super }
end
```

If you want to find all records, even those which are deleted:

``` ruby
Client.with_deleted
```

If you want to find only the deleted records:

``` ruby
Client.only_deleted
```

If you want to check if a record is soft-deleted:

``` ruby
client.destroyed?
```

If you want to restore a record:

``` ruby
Client.restore(id)
```

If you want to restore a whole bunch of records:

``` ruby
Client.restore([id1, id2, ..., idN])
```

If you want to restore a record and their dependently destroyed associated records:

``` ruby
Client.restore(id, :recursive => true)
```

If you want callbacks to trigger before a restore:

``` ruby
before_restore :callback_name_goes_here
```

For more information, please look at the tests.

## Acts As Paranoid Migration

You can replace the older `acts_as_paranoid` methods as follows:

| Old Syntax                 | New Syntax                     |
|:-------------------------- |:------------------------------ |
|`find_with_deleted(:all)`   | `Client.with_deleted`          |
|`find_with_deleted(:first)` | `Client.with_deleted.first`    |
|`find_with_deleted(id)`     | `Client.with_deleted.find(id)` |

## Support for Unique Keys with Null Values

With most databases, a unique key will not be enforced when it contains a
nullable value because each row's null will be treated unique.

``` ruby
class AddDeletedAtToClients < ActiveRecord::Migration
  def change
    add_column :clients, :deleted_at, :datetime
    add_index :clients, [:username, :deleted_at], unique: true
  end
end
```

Given the migration above, you could have multiple users with username bob given the following inserts: ('bob', null), ('bob', null), ('bob', null). We can agree this is not the expected behavior.

To avoid this problem, we could use a flag column instead of a datetime, but the datetime value has intrinsic usefulness.  Instead, we can add a second column for the unique key that always has a value, in this case 0 or 1:

``` ruby
class AddDeletedAtToClients < ActiveRecord::Migration
  def change
    add_column :clients, :deleted_at, :datetime
    add_column :clients, :is_deleted, :boolean, null: false, default: 0
    add_index :clients, [:username, :is_deleted], unique: true
  end
end
```

Support this new column by updating your model as such:

``` ruby
class Client < ActiveRecord::Base
  acts_as_paranoid :flag_column => :is_deleted
  ...
end
```

If you create an index on the flag column, and you want paranoia to use that index instead of deleted_at, you can add `:index_column => :is_deleted` to the acts_as_paranoid definition.

## License

This gem is released under the MIT license.
