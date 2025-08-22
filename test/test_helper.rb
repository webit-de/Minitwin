$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

begin
  require "simplecov"
  SimpleCov.start do
    add_filter "/test/"
  end
rescue LoadError
  # SimpleCov is optional
end

require "minitest/autorun"
require "shoulda/context"

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
