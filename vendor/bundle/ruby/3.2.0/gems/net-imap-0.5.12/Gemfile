# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "digest"
gem "strscan"
gem "base64"

gem "irb"
gem "rake"
gem "rdoc"
gem "test-unit"
gem "test-unit-ruby-core", git: "https://github.com/ruby/test-unit-ruby-core"

gem "benchmark", require: false
gem "benchmark-driver", require: false
gem "vernier", require: false, platform: :mri

group :test do
  gem "simplecov",        require: false, platforms: %i[mri windows]
  gem "simplecov-html",   require: false, platforms: %i[mri windows]
  gem "simplecov-json",   require: false, platforms: %i[mri windows]
end
