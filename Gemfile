source "https://rubygems.org"

gem "rails", "~> 8.1.1"
gem "propshaft"
gem "pg", "~> 1.1"
gem "sqlite3"
gem "puma", ">= 5.0"

# Frontend
gem "vite_rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "dartsass-rails"

# Infrastructure
gem "solid_cache"
gem "solid_cable"
gem "solid_queue"
gem "mission_control-jobs"
gem "bootsnap", require: false
gem "kamal", require: false
gem "thruster", require: false
gem "tzinfo-data", platforms: %i[windows jruby]

# Storage & Media
gem "aws-sdk-s3", require: false
gem "image_processing", "~> 1.2"
gem "mini_exiftool"

# Auth & Policy
gem "action_policy"

# UI
gem "view_component"
gem "simple_form"

# Domain
gem "ancestry"
gem "geocoder"
gem "faker"
gem "resend"

group :test do
  gem "shoulda-matchers"
  gem "webmock"
  gem "simplecov", require: false
end

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "rspec-rails", "~> 8.0.0"
  gem "factory_bot_rails"
end

group :development do
  gem "web-console"
  gem "guard"
  gem "guard-rspec", require: false
end
