require "test_helper"
require "mini_twin"

class CAddressTwin < MiniTwin
  property :street
  property :city
end

class CItemTwin < MiniTwin
  property :name, validates: { presence: true }
  property :quantity, type: Types::Params::Integer.lax, default: 0
  property :block_in_item do
    property :note
  end
end

class CombinedTwin < MiniTwin
  # Scalars with options
  property :count, type: Types::Params::Integer.lax, default: 1
  property :name, validates: { presence: true }
  property :enabled, type: Types::Params::Bool.lax, default: false
  property :virtual_secret, virtual: true
  property :computed_upper, getter: -> { name.to_s.upcase }
  property :shifted_date, setter: ->(days) { days.days.from_now.to_date }

  # Block property
  property :profile do
    property :bio
    property :age, type: Types::Params::Integer.lax
  end

  # Embedded twin
  property :address, twin: CAddressTwin

  # Collection with alias and twin
  collection :items, as: :line_items, twin: CItemTwin, default: []

  # Nested grouping with deeper nesting
  nested :settings do
    property :theme, default: "light"
    nested :notifications do
      property :email, default: false
    end
  end

  # Composition from external objects
  property :id, as: :customer_id, on: :customer
  property :street, on: :shipping
  property :latitude, on: :shipping, virtual: true
end

class CombinedTwinTest < ActiveSupport::TestCase
  should "build, compose, and serialize a fully-featured twin" do
    # External models for composition
    customer = Data.define(:id, :name).new(id: 42, name: "Alice")
    shipping = Data.define(:street, :latitude).new(street: "Ruby Rd", latitude: 12.34)

    twin = CombinedTwin.from_objects(customer:, shipping:)

    # Assign remaining attributes via hash (coercions + nested proxies)
    twin.assign_hash(
      name: "alice",
      count: "7",
      enabled: "1",
      virtual_secret: "hidden",
      shifted_date: 1,
      profile: { bio: "builder", age: "30" },
      address: { street: "Rails Ave", city: "Sinatra" },
      theme: "dark",
      email: true
    )

    # Set collection via explicit writer since aliased getter is protected
    twin.items = [
      { name: "widget", quantity: "2", block_in_item: { note: "ok" } },
      { name: "gadget", block_in_item: { note: "fine" } }
    ]

    # Scalars and coercions
    assert_equal 7, twin.count
    assert_equal true, twin.enabled
    assert_equal "ALICE", twin.computed_upper
    assert_equal Date.tomorrow, twin.shifted_date

    # Block property
    assert_equal "builder", twin.profile.bio
    assert_equal 30, twin.profile.age

    # Embedded twin
    assert_instance_of CAddressTwin, twin.address
    assert_equal "Rails Ave", twin.address.street
    assert_equal "Sinatra", twin.address.city

    # Collection with alias and defaults
    assert_equal 2, twin.line_items.size
    assert_equal ["widget", "gadget"], twin.line_items.map(&:name)
    assert_equal [2, 0], twin.line_items.map(&:quantity)
    assert_equal ["ok", "fine"], twin.line_items.map { |it| it.block_in_item.note }
    assert_respond_to twin, :items_attributes=

    # Nested grouping via proxies
    assert_equal "dark", twin.settings.theme
    assert_equal true, twin.settings.notifications.email

    # Composition
    assert_equal 42, twin.customer_id
    assert_equal "Ruby Rd", twin.street

    # Serialization checks
    h = twin.to_hash
    # HashWithIndifferentAccess output
    assert h.is_a?(ActiveSupport::HashWithIndifferentAccess)
    # Aliased id present, original hidden
    assert_equal 42, h[:customer_id]
    assert_nil h[:id]
    # Virtuals omitted
    assert_nil h[:virtual_secret]
    assert_nil h[:latitude]
    # Block property structure
    assert_equal "builder", h[:profile][:bio]
    assert_equal 30, h[:profile][:age]
    # Embedded twin serialized
    assert_equal "Rails Ave", h[:address][:street]
    assert_equal "Sinatra", h[:address][:city]
    # Collection serialized with elements and nested blocks
    assert_equal 2, h[:line_items].size
    assert_equal "widget", h[:line_items].first[:name]
    assert_equal 2, h[:line_items].first[:quantity]
    assert_equal "ok", h[:line_items].first[:block_in_item][:note]
    # Nested grouping only under :settings; proxies hidden
    refute h.key?(:theme)
    refute h.key?(:email)
    assert_equal "dark", h[:settings][:theme]
    assert_equal true, h[:settings][:notifications][:email]

    # JSON equivalent
    parsed = JSON.parse(twin.to_json)
    assert_equal 42, parsed["customer_id"]
    assert_equal "Ruby Rd", parsed["street"]
    assert_equal "ALICE", parsed["computed_upper"]
    assert_equal "builder", parsed.dig("profile", "bio")
    assert_equal "Rails Ave", parsed.dig("address", "street")
    assert_equal "widget", parsed.dig("line_items", 0, "name")
    assert_equal "dark", parsed.dig("settings", "theme")
    assert_equal true, parsed.dig("settings", "notifications", "email")
    refute parsed.key?("virtual_secret")
    refute parsed.key?("latitude")
  end
end
