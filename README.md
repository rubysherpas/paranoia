**Notice:** 

`paranoia` has some surprising behaviour (like overriding ActiveRecord's `delete` and `destroy`) and is not recommended for new projects. See [`discard`'s README](https://github.com/jhawthorn/discard#why-not-paranoia-or-acts_as_paranoid) for more details.

Paranoia will continue to accept bug fixes and support new versions of Rails but isn't accepting new features.

# Paranoia

Paranoia is a re-implementation of [acts\_as\_paranoid](http://github.com/ActsAsParanoid/acts_as_paranoid) for Rails 3/4/5, using much, much, much less code.

When your app is using Paranoia, calling `destroy` on an ActiveRecord object doesn't actually destroy the database record, but just *hides* it. Paranoia does this by setting a `deleted_at` field to the current time when you `destroy` a record, and hides it by scoping all queries on your model to only include records which do not have a `deleted_at` field.

If you wish to actually destroy an object you may call `really_destroy!`. **WARNING**: This will also *really destroy* all `dependent: :destroy` records, so please aim this method away from face when using.

If a record has `has_many` associations defined AND those associations have `dependent: :destroy` set on them, then they will also be soft-deleted if `acts_as_paranoid` is set, otherwise the normal destroy will be called. ***See [Destroying through association callbacks](#destroying-through-association-callbacks) for clarifying examples.***

## Getting Started Video
Setup and basic usage of the paranoia gem
[GoRails #41](https://gorails.com/episodes/soft-delete-with-paranoia)

## Installation & Usage

For Rails 3, please use version 1 of Paranoia:

``` ruby
gem "paranoia", "~> 1.0"
```

For Rails 4 and 5, please use version 2 of Paranoia (2.2 or greater required for rails 5):

``` ruby
gem "paranoia", "~> 2.2"
```

Of course you can install this from GitHub as well from one of these examples:

``` ruby
gem "paranoia", github: "rubysherpas/paranoia", branch: "rails3"
gem "paranoia", github: "rubysherpas/paranoia", branch: "rails4"
gem "paranoia", github: "rubysherpas/paranoia", branch: "rails5"
```

Then run:

``` shell
bundle install
```

Updating is as simple as `bundle update paranoia`.

#### Run your migrations for the desired models

Run:

``` shell
bin/rails generate migration AddDeletedAtToClients deleted_at:datetime:index
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

If you want to use a column other than `deleted_at`, you can pass it as an option:

``` ruby
class Client < ActiveRecord::Base
  acts_as_paranoid column: :destroyed_at

  ...
end
```


If you want to skip adding the default scope:

``` ruby
class Client < ActiveRecord::Base
  acts_as_paranoid without_default_scope: true

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

If you want to exclude deleted records, when not able to use the default_scope (e.g. when using without_default_scope):

``` ruby
Client.without_deleted
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

If you want to restore a record and only those dependently destroyed associated records that were deleted within 2 minutes of the object upon which they depend:

``` ruby
Client.restore(id, :recursive => true. :recovery_window => 2.minutes)
# or
client.restore(:recursive => true, :recovery_window => 2.minutes)
```

Note that by default paranoia will not prevent that a soft destroyed object can't be associated with another object of a different model.
A Rails validator is provided should you require this functionality:
  ``` ruby
validates :some_assocation, association_not_soft_destroyed: true
```
This validator makes sure that `some_assocation` is not soft destroyed. If the object is soft destroyed the main object is rendered invalid and an validation error is added.

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

##### Unique Indexes

Because NULL != NULL in standard SQL, we can not simply create a unique index
on the deleted_at column and expect it to enforce that there only be one record
with a certain combination of values.

If your database supports them, good alternatives include partial indexes
(above) and indexes on computed columns. E.g.

``` ruby
add_index :clients, [:group_id, 'COALESCE(deleted_at, false)'], unique: true
```

If not, an alternative is to create a separate column which is maintained
alongside deleted_at for the sake of enforcing uniqueness. To that end,
paranoia makes use of two method to make its destroy and restore actions:
paranoia_restore_attributes and paranoia_destroy_attributes.

``` ruby
add_column :clients, :active, :boolean
add_index :clients, [:group_id, :active], unique: true

class Client < ActiveRecord::Base
  # optionally have paranoia make use of your unique column, so that
  # your lookups will benefit from the unique index
  acts_as_paranoid column: :active, sentinel_value: true

  def paranoia_restore_attributes
    {
      deleted_at: nil,
      active: true
    }
  end

  def paranoia_destroy_attributes
    {
      deleted_at: current_time_from_proper_timezone,
      active: nil
    }
  end
end
```

##### Destroying through association callbacks

When dealing with `dependent: :destroy` associations and `acts_as_paranoid`, it's important to remember that whatever method is called on the parent model will be called on the child model. For example, given both models of an association have `acts_as_paranoid` defined:

``` ruby
class Client < ActiveRecord::Base
  acts_as_paranoid

  has_many :emails, dependent: :destroy
end

class Email < ActiveRecord::Base
  acts_as_paranoid

  belongs_to :client
end
```

When we call `destroy` on the parent `client`, it will call `destroy` on all of its associated children `emails`:

``` ruby
>> client.emails.count
# => 5
>> client.destroy
# => client
>> client.deleted_at
# => [current timestamp]
>> Email.where(client_id: client.id).count
# => 0
>> Email.with_deleted.where(client_id: client.id).count
# => 5
```

Similarly, when we call `really_destroy!` on the parent `client`, then each child `email` will also have `really_destroy!` called:

``` ruby
>> client.emails.count
# => 5
>> client.id
# => 12345
>> client.really_destroy!
# => client
>> Client.find 12345
# => ActiveRecord::RecordNotFound
>> Email.with_deleted.where(client_id: client.id).count
# => 0
```

However, if the child model `Email` does not have `acts_as_paranoid` set, then calling `destroy` on the parent `client` will also call `destroy` on each child `email`, thereby actually destroying them:

``` ruby
class Client < ActiveRecord::Base
  acts_as_paranoid

  has_many :emails, dependent: :destroy
end

class Email < ActiveRecord::Base
  belongs_to :client
end

>> client.emails.count
# => 5
>> client.destroy
# => client
>> Email.where(client_id: client.id).count
# => 0
>> Email.with_deleted.where(client_id: client.id).count
# => NoMethodError: undefined method `with_deleted' for #<Class:0x0123456>
```

## Acts As Paranoid Migration

You can replace the older `acts_as_paranoid` methods as follows:

| Old Syntax                 | New Syntax                     |
|:-------------------------- |:------------------------------ |
|`find_with_deleted(:all)`   | `Client.with_deleted`          |
|`find_with_deleted(:first)` | `Client.with_deleted.first`    |
|`find_with_deleted(id)`     | `Client.with_deleted.find(id)` |


The `recover` method in `acts_as_paranoid` runs `update` callbacks.  Paranoia's
`restore` method does not do this.

## Callbacks

Paranoia provides several callbacks. It triggers `destroy` callback when the record is marked as deleted and `real_destroy` when the record is completely removed from database. It also calls `restore` callback when the record is restored via paranoia

For example if you want to index your records in some search engine you can go like this:

```ruby
class Product < ActiveRecord::Base
  acts_as_paranoid

  after_destroy      :update_document_in_search_engine
  after_restore      :update_document_in_search_engine
  after_real_destroy :remove_document_from_search_engine
end
```

You can use these events just like regular Rails callbacks with before, after and around hooks.

## License

This gem is released under the MIT license.
