require "json"
require "set"
require "dry-types"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/hash_with_indifferent_access"

begin
  require "active_model"
rescue LoadError
end

require_relative "mini_twin/version"
require_relative "mini_twin/types"
require_relative "mini_twin/initialization"
require_relative "mini_twin/assignment"
require_relative "mini_twin/serialization"
require_relative "mini_twin/class_methods"

class MiniTwin
  include ActiveModel::Model if defined?(ActiveModel::Model)
  include MiniTwin::Initialization
  include MiniTwin::Assignment
  include MiniTwin::Serialization
  extend  MiniTwin::ClassMethods
end

