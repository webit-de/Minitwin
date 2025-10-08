require "test_helper"
require "mini_twin"

class FromParamsTwin < MiniTwin
  property :x, type: Types::Params::Integer.lax
  property :y
  property :string, type: Types::Params::String.lax
  property :not_given, type: Types::Params::Integer.lax
end

class FromParamsTest < ActiveSupport::TestCase
  should "build from ActionController::Parameters" do
    params = ActionController::Parameters.new(x: "7", y: "ok", string: 1)
    t = FromParamsTwin.from_params(params)
    assert_equal 7, t.x
    assert_equal "ok", t.y
    assert_equal 0, t.not_given
    assert_equal "1", t.string
  end

  should "build from plain hash" do
    t = FromParamsTwin.from_params({ x: "9", y: "fine" })
    assert_equal 9, t.x
    assert_equal "fine", t.y
  end
end

