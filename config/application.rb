require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module Photos
  class Application < Rails::Application
    config.load_defaults 8.1

    config.autoload_lib(ignore: %w[assets tasks])

    config.time_zone = "UTC"
    config.active_record.schema_format = :sql
    config.active_record.default_timezone = :utc
    config.active_record.time_zone_aware_types = [ :datetime, :timestamp, :timestamptz ]

    config.generators.system_tests = nil

    config.action_mailer.delivery_method = :resend
  end
end
