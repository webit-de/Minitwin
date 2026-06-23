# frozen_string_literal: true

require "dry/types"

# Equivalent "User" schema in each benchmarked library. Competitor requires are
# guarded so a missing gem skips that library instead of aborting the suite.
module Bench
  module Types
    include Dry.Types()
  end

  AVAILABLE = {}

  # --- minitwin (always present; loaded from local lib/) ---
  require "minitwin"
  class MtUser < Minitwin
    property :id,     type: Bench::Types::Params::Integer.lax
    property :name,   validates: { presence: true }
    property :active, type: Bench::Types::Params::Bool.lax
    property :address do
      property :city
      property :zip
    end
    collection :roles
  end
  AVAILABLE[:minitwin] = true

  # --- disposable ---
  begin
    require "disposable/twin"
    require "disposable/twin/sync"
    class DispUser < Disposable::Twin
      feature Disposable::Twin::Sync
      property :id
      property :name
      property :active
      property :address do
        property :city
        property :zip
      end
      collection :roles
    end
    AVAILABLE[:disposable] = true
  rescue LoadError
    AVAILABLE[:disposable] = false
    warn "[bench] skipped — disposable not installed"
  end

  # --- representable ---
  begin
    require "representable/hash"
    require "representable/json"
    class UserRepresenter < Representable::Decorator
      include Representable::Hash
      include Representable::JSON
      property :id
      property :name
      property :active
      property :address do
        property :city
        property :zip
      end
      collection :roles
    end
    AVAILABLE[:representable] = true
  rescue LoadError
    AVAILABLE[:representable] = false
    warn "[bench] skipped — representable not installed"
  end

  # --- reform (validation peer; uses the ActiveModel backend, like minitwin) ---
  begin
    require "reform"
    require "reform/form/active_model/validations"
    class UserForm < Reform::Form
      include Reform::Form::ActiveModel::Validations
      property :id
      property :name
      property :active
      property :address do
        include Reform::Form::ActiveModel::Validations
        property :city
        property :zip
      end
      collection :roles
      validates :name, presence: true
    end
    AVAILABLE[:reform] = true
  rescue LoadError
    AVAILABLE[:reform] = false
    warn "[bench] skipped — reform not installed"
  end
end
