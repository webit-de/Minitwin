# frozen_string_literal: true

# Configure SimpleCov before loading any application code
require "simplecov"
SimpleCov.start do
  add_filter "/test/"
  add_filter "/vendor/"
  add_filter "/lib/mini_twin.rb"
  enable_coverage :branch
  minimum_coverage line: 99, branch: 80
end

# Surface Ruby deprecation warnings (deprecate_constant et al.) during tests.
# Defaults to false on Ruby 3.0+; we enable it so the suite exercises and
# verifies the deprecation signal.
Warning[:deprecated] = true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"

# ActiveSupport goodies used in tests (e.g., HashWithIndifferentAccess, time helpers)
require "active_support/test_case"
require "active_support/time"
require "active_support/core_ext/array/access"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/hash_with_indifferent_access"
require "active_support/core_ext/object/blank"

# ActionController::Parameters used by assign_params
require "action_controller"

# Ensure ActiveModel is loaded so validations are available
require "active_model"

# Provide Types shorthand for dry-types in tests
# (Minitwin no longer ships its own Types module)
require "mini_twin"
module Types
  include Dry.Types()
end

# uncomment class definition if global things needed
# class ActiveSupport::TestCase
#   # Global test setup can go here
# end
