# frozen_string_literal: true

source "https://rubygems.org"
ruby ">= 3.3"

gemspec

group :development, :test do
  # Lock optional tools if needed here
  gem "actionpack", ">= 6.1"
  gem "activemodel", ">= 6.1"
  gem "dry-types", ">= 1.7"
  gem "m", ">= 1.6"
  gem "minitest", ">= 5.18"
  gem "rake", ">= 13.0"
  gem "rbs-inline"
  gem "rubocop-performance", "1.26.1", require: false
  gem "simplecov", ">= 0.22"
  gem "webit-ruby-rubocop", ">= 3.1", require: false
end

group :benchmark do
  gem "benchmark-ips", ">= 2.14"
  gem "benchmark-memory", ">= 0.2"
  gem "disposable", ">= 0.6"
  gem "representable", ">= 3.2"
  gem "reform", ">= 2.6"
  # reform-rails supplies Reform's ActiveModel validation backend (apples-to-apples
  # with minitwin); plain reform 2.6 only ships the dry-validation backend.
  gem "reform-rails", ">= 0.3"
  gem "ostruct"
  gem "multi_json"
end
