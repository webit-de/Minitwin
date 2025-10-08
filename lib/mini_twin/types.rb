class MiniTwin
  # Thin wrapper exposing Dry::Types. Usage:
  #   property :id, type: Types::Params::Integer.lax
  module Types
    include Dry.Types()
  end
end
