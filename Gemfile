source 'https://rubygems.org'

sqlite = ENV['SQLITE_VERSION']

if sqlite
  gem 'sqlite3', sqlite, platforms: [:ruby]
else
  gem 'sqlite3', platforms: [:ruby]
end

platforms :jruby do
  gem 'activerecord-jdbcsqlite3-adapter'
end

platforms :rbx do
  gem 'rubinius-developer_tools'
  gem 'rubysl', '~> 2.0'
  gem 'rubysl-test-unit'
end

rails = ENV['RAILS'] || '~> 5.2.0'

if rails == 'master'
  gem 'rails', github: 'rails/rails'
else
  gem 'rails', rails
end

# Specify your gem's dependencies in paranoia.gemspec
gemspec
