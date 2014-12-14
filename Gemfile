source 'https://rubygems.org'

gem 'sqlite3', :platforms => [:ruby]
gem 'activerecord-jdbcsqlite3-adapter', :platforms => [:jruby]

platforms :rbx do
  gem 'rubysl', '~> 2.0'
  gem 'rubysl-test-unit'
  gem 'rubinius-developer_tools'
end

rails = ENV['RAILS'] || '~> 4.2.0'

gem 'rails', rails

# Specify your gem's dependencies in paranoia.gemspec
gemspec
