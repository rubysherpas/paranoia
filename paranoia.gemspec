# -*- encoding: utf-8 -*-
require File.expand_path("../lib/paranoia/version", __FILE__)

Gem::Specification.new do |s|
  s.name        = "paranoia"
  s.version     = Paranoia::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["radarlistener@gmail.com"]
  s.email       = []
  s.homepage    = "http://rubygems.org/gems/paranoia"
  s.summary     = "Paranoia is a re-implementation of acts_as_paranoid for Rails 3, using much, much, much less code."
  s.description = "Paranoia is a re-implementation of acts_as_paranoid for Rails 3, using much, much, much less code. You would use either plugin / gem if you wished that when you called destroy on an Active Record object that it didn't actually destroy it, but just \"hid\" the record. Paranoia does this by setting a deleted_at field to the current time when you destroy a record, and hides it by scoping all queries on your model to only include records which do not have a deleted_at field."

  s.required_rubygems_version = ">= 1.3.6"
  s.rubyforge_project         = "paranoia"
  
  s.add_dependency "activerecord", ">= 3.0.0"

  s.add_development_dependency "bundler", ">= 1.0.0"
  s.add_development_dependency "sqlite3"
  s.add_development_dependency "rake", "0.8.7"
  
  s.files        = `git ls-files`.split("\n")
  s.executables  = `git ls-files`.split("\n").map{|f| f =~ /^bin\/(.*)/ ? $1 : nil}.compact
  s.require_path = 'lib'
end
