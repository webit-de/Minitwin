# frozen_string_literal: true

require "test_helper"
require "minitwin"

class RoundTripTest < ActiveSupport::TestCase
  class TokenTwin < Minitwin
    property :internal_token, as: :token
  end

  class TagsTwin < Minitwin
    collection :internal_tags, as: :tags
  end

  class ProfileTwin < Minitwin
    property :username
    nested :settings, as: :"app:settings" do
      property :theme
    end
  end

  class FieldTwin < Minitwin
    property :key
    property :value, as: -> { key }
  end

  class ReadonlyFieldTwin < Minitwin
    property :key
    property :value, as: -> { key }, readonly: true
  end

  class NestedFieldTwin < Minitwin
    property :label
    nested :field do
      property :key
      property :value, as: -> { key }
    end
  end

  test "accepts the serialized key of a statically aliased property" do
    assert_equal "abc", TokenTwin.from_hash(token: "abc").token
  end

  test "still accepts the original name of a statically aliased property" do
    assert_equal "abc", TokenTwin.from_hash(internal_token: "abc").token
  end

  test "accepts the serialized key of a statically aliased collection" do
    assert_equal %w[a b], TagsTwin.from_hash(tags: %w[a b]).tags
  end

  test "accepts the serialized key of an aliased nested container" do
    twin = ProfileTwin.from_hash("app:settings" => { theme: "dark" }, :username => "dana")

    assert_equal "dark", twin.theme
  end

  test "accepts the serialized key of a dynamically aliased property" do
    assert_equal 42, FieldTwin.from_hash(key: "score", score: 42).score
  end

  test "accepts a dynamically aliased key inside a nested twin" do
    twin = NestedFieldTwin.from_hash(label: "x", field: { key: "score", score: 42 })

    assert_equal 42, twin.field.score
  end

  test "assign_hash accepts the serialized key of a statically aliased property" do
    twin = TokenTwin.new(internal_token: "old")

    assert_equal "new", twin.assign_hash(token: "new").token
  end

  test "assign_hash accepts the serialized key of a dynamically aliased property" do
    twin = FieldTwin.new(key: "score", value: 1)

    assert_equal 42, twin.assign_hash(score: 42).score
  end

  test "assign_hash ignores the serialized key of a readonly dynamically aliased property" do
    twin = ReadonlyFieldTwin.new(key: "score", value: 1)

    assert_equal 1, twin.assign_hash(score: 42).score
  end

  test "round-trips to_hash through from_hash" do
    original = ProfileTwin.new(username: "dana", theme: "dark")

    assert_equal original.to_hash, ProfileTwin.from_hash(original.to_hash).to_hash
  end

  test "round-trips to_json through from_json" do
    original = FieldTwin.new(key: "score", value: 42)

    assert_equal original.to_hash, FieldTwin.from_json(original.to_json).to_hash
  end
end
