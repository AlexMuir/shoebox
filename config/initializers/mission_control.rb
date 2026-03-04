# Skip HTTP basic auth — access is controlled by the route constraint in routes.rb
MissionControl::Jobs.base_controller_class = "ApplicationController"
MissionControl::Jobs.http_basic_auth_enabled = false
