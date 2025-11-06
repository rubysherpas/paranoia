source 'https://rubygems.org'

rails = ENV['RAILS'] || '~> 7.0.0'
sqlite = ENV['SQLITE_VERSION']

if sqlite
  gem 'sqlite3', sqlite, platforms: [:ruby]
elsif rails.start_with?('~> 8')
  gem 'sqlite3', '~> 2.1', platforms: [:ruby]
else
  gem 'sqlite3', '~> 1.4', platforms: [:ruby]
end

platforms :jruby do
  gem 'activerecord-jdbcsqlite3-adapter'
end

if RUBY_ENGINE == 'rbx'
  platforms :rbx do
    gem 'rubinius-developer_tools'
    gem 'rubysl', '~> 2.0'
    gem 'rubysl-test-unit'
  end
end

if rails == 'edge'
  gem 'rails', github: 'rails/rails'
else
  gem 'rails', rails
end

# Specify your gem's dependencies in paranoia.gemspec
gemspec
