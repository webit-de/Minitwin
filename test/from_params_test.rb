require "test_helper"
require "mini_twin"

class FromParamsTwin < MiniTwin
  property :x, type: Types::Params::Integer.lax
  property :y
end

class FromParamsTest < ActiveSupport::TestCase
  should "build from ActionController::Parameters" do
    params = ActionController::Parameters.new(x: "7", y: "ok")
    t = FromParamsTwin.from_params(params)
    assert_equal 7, t.x
    assert_equal "ok", t.y
  end

  should "build from plain hash" do
    t = FromParamsTwin.from_params({ x: "9", y: "fine" })
    assert_equal 9, t.x
    assert_equal "fine", t.y
  end
end

