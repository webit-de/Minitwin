require "test_helper"
require "mini_twin"

class FromJsonTwin < MiniTwin
  property :id, type: Types::Params::Integer.lax
  property :name
end

class FromJsonTest < ActiveSupport::TestCase
  should "build from JSON with symbolized keys" do
    json = { id: "12", name: "Alice" }.to_json
    t = FromJsonTwin.from_json(json)
    assert_equal 12, t.id
    assert_equal "Alice", t.name
  end
end

