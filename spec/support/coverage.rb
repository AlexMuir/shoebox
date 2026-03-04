# frozen_string_literal: true

if ENV["COVERAGE"]
  require "simplecov"

  SimpleCov.start "rails" do
    add_filter "/spec/"
    add_filter "/config/"
    add_filter "/vendor/"

    add_group "Models", "app/models"
    add_group "Controllers", "app/controllers"
    add_group "Helpers", "app/helpers"
    add_group "Mailers", "app/mailers"
    add_group "Jobs", "app/jobs"
    add_group "Policies", "app/policies"
    add_group "Components", "app/components"
  end
end
