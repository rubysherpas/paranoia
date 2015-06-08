# Paranoia

Paranoia is a re-implementation of [acts\_as\_paranoid](http://github.com/technoweenie/acts_as_paranoid) for Rails 3 and Rails 4, using much, much, much less code.

You would use either plugin / gem if you wished that when you called `destroy` on an Active Record object that it didn't actually destroy it, but just *hide* the record. Paranoia does this by setting a `deleted_at` field to the current time when you `destroy` a record, and hides it by scoping all queries on your model to only include records which do not have a `deleted_at` field.

If you wish to actually destroy an object you may call `really_destroy!`. **WARNING**: This will also *really destroy* all `dependent: :destroy` records, so please aim this method away from face when using.

If a record has `has_many` associations defined AND those associations have `dependent: :destroy` set on them, then they will also be soft-deleted if `acts_as_paranoid` is set,  otherwise the normal destroy will be called.

## Getting Started Video
Setup and basic usage of the paranoia gem  
[GoRails #41](https://gorails.com/episodes/soft-delete-with-paranoia)

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
gem "paranoia", :github => "radar/paranoia", :branch => "rails3"
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

If you want to include associated soft-deleted objects, you can (un)scope the association:

``` ruby
class Person < ActiveRecord::Base
  belongs_to :group, -> { with_deleted }
end

Person.includes(:group).all
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
client.paranoia_destroyed?
# or
client.deleted?
```

If you want to restore a record:

``` ruby
Client.restore(id)
# or
client.restore
```

If you want to restore a whole bunch of records:

``` ruby
Client.restore([id1, id2, ..., idN])
```

If you want to restore a record and their dependently destroyed associated records:

``` ruby
Client.restore(id, :recursive => true)
# or
client.restore(:recursive => true)
```

If you want callbacks to trigger before a restore:

``` ruby
before_restore :callback_name_goes_here
```

For more information, please look at the tests.

#### About indexes:

Beware that you should adapt all your indexes for them to work as fast as previously.
For example,

``` ruby
add_index :clients, :group_id
add_index :clients, [:group_id, :other_id]
```

should be replaced with

``` ruby
add_index :clients, :group_id, where: "deleted_at IS NULL"
add_index :clients, [:group_id, :other_id], where: "deleted_at IS NULL"
```

Of course, this is not necessary for the indexes you always use in association with `with_deleted` or `only_deleted`.

## Acts As Paranoid Migration

You can replace the older `acts_as_paranoid` methods as follows:

| Old Syntax                 | New Syntax                     |
|:-------------------------- |:------------------------------ |
|`find_with_deleted(:all)`   | `Client.with_deleted`          |
|`find_with_deleted(:first)` | `Client.with_deleted.first`    |
|`find_with_deleted(id)`     | `Client.with_deleted.find(id)` |


The `recover` method in `acts_as_paranoid` runs `update` callbacks.  Paranoia's
`restore` method does not do this.

## License

This gem is released under the MIT license.
