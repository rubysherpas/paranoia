# Paranoia

Paranoia is a re-implementation of [acts\_as\_paranoid](http://github.com/technoweenie/acts_as_paranoid) for Rails 3, using much, much, much less code.

You would use either plugin / gem if you wished that when you called `destroy` on an Active Record object that it didn't actually destroy it, but just "hid" the record. Paranoia does this by setting a `deleted_at` field to the current time when you `destroy` a record, and hides it by scoping all queries on your model to only include records which do not have a `deleted_at` field.

## Installation & Usage

### Initial installation

#### Rails 3

In your _Gemfile_:

    gem 'paranoia'

Then run:

    bundle install

#### Rails 2:

In your _config/environment.rb_:

    config.gem 'paranoia'

Then run:

    rake gems:install

### Usage

#### In your model:

    class Client < ActiveRecord::Base
      acts_as_paranoid
      
      ...
    end

Hey presto, it's there!

If you want a method to be called on destroy, simply provide a _before\_destroy_ callback:

    class Client < ActiveRecord::Base
      acts_as_paranoid

      before_destroy :some_method

      def some_method
        # do stuff
      end

      ...
    end

## License

This gem is released under the MIT license.