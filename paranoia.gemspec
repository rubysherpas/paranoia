# -*- encoding: utf-8 -*-
require File.expand_path("../lib/paranoia/version", __FILE__)

Gem::Specification.new do |s|
  s.name        = "paranoia"
  s.version     = Paranoia::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = %w(radarlistener@gmail.com)
  s.email       = %w(ben@benmorgan.io john.hawthorn@gmail.com)
  s.homepage    = "https://github.com/rubysherpas/paranoia"
  s.license     = 'MIT'
  s.summary     = "Paranoia is a re-implementation of acts_as_paranoid for Rails 3, 4, and 5, using much, much, much less code."
  s.description = <<-DSC
    Paranoia is a re-implementation of acts_as_paranoid for Rails 3, 4, and 5,
    using much, much, much less code. You would use either plugin / gem if you
    wished that when you called destroy on an Active Record object that it
    didn't actually destroy it, but just "hid" the record. Paranoia does this
    by setting a deleted_at field to the current time when you destroy a record,
    and hides it by scoping all queries on your model to only include records
    which do not have a deleted_at field.
  DSC

  s.required_rubygems_version = ">= 1.3.6"

  s.required_ruby_version = '>= 2.0'

  s.add_dependency 'activerecord', '>= 4.0', '< 6.1'

  s.add_development_dependency "bundler", ">= 1.0.0"
  s.add_development_dependency "rake"

  s.files        = `git ls-files`.split("\n")
  s.executables  = `git ls-files`.split("\n").map{|f| f =~ /^bin\/(.*)/ ? $1 : nil}.compact
  s.require_path = 'lib'
end
