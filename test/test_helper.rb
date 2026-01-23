# Configure SimpleCov before loading any application code
require "simplecov"
SimpleCov.start do
  add_filter "/test/"
  add_filter "/vendor/"
  add_filter "/lib/mini_twin.rb"
  enable_coverage :branch
  minimum_coverage line: 100, branch: 80
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"

# ActiveSupport goodies used in tests (e.g., HashWithIndifferentAccess, time helpers)
require "active_support/test_case"
require "active_support/time"
require "active_support/core_ext/array/access"

# ActionController::Parameters used by assign_params
require "action_controller"

# Ensure ActiveModel is loaded so validations are available
require "active_model"

class ActiveSupport::TestCase
  # Global test setup can go here
end
