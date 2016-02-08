# -*- encoding: utf-8 -*-
require File.expand_path("../lib/paranoia/version", __FILE__)

Gem::Specification.new do |s|
  s.name        = "paranoia"
  s.version     = Paranoia::VERSION
  s.authors     = ["Kurtis Rainbolt-Greene (@krainboltgreene) <me@kurtisrainboltgreene>"]
  s.homepage    = "https://rubysherpas.github.io/paranoia"
  s.summary     = "Paranoia is a re-implementation of acts_as_paranoid for Rails 3, using much, much, much less code."
  s.description = s.summary
  s.required_ruby_version = '>= 2.0'

  s.add_dependency 'activerecord', '>= 4.0', '< 5.1'

  s.add_development_dependency "bundler"
  s.add_development_dependency "rake"

  s.files        = `git ls-files`.split("\n")
  s.executables  = `git ls-files`.split("\n").map{|f| f =~ /^bin\/(.*)/ ? $1 : nil}.compact
  s.require_path = 'lib'
end
