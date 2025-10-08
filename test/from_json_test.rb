require "test_helper"
require "mini_twin"

class FromJsonTwin < MiniTwin
  property :id, type: Types::Params::Integer.lax
  property :name
  property :string, type: Types::Params::String.lax
  property :date, type: Types::Params::Date.lax
  property :not_given_date, type: Types::Params::Date.lax
end

class FromJsonTest < ActiveSupport::TestCase
  test "should build from JSON with symbolized keys" do
    json = { id: "12", name: "Alice", string: 1, date: '2025-05-23' }.to_json
    t = FromJsonTwin.from_json(json)
    assert_equal 12, t.id
    assert_equal "Alice", t.name
    assert_instance_of Date, t.date
    assert_equal "1", t.string
    assert_equal nil, t.not_given_date
  end
end

