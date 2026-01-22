require "test_helper"
require "mini_twin"

class SyncNestedTest < ActiveSupport::TestCase
  ContactModel = Struct.new(:email)
  ProfileModel = Struct.new(:bio, :contact)
  UserModel = Struct.new(:name, :profile)

  class UserTwin < MiniTwin
    property :name
    property :profile do
      property :bio
      property :contact do
        property :email
      end
    end
  end

  test "sync defaults to stored model and deep-syncs nested twins" do
    contact = ContactModel.new("old@example.com")
    profile = ProfileModel.new("Old bio", contact)
    user = UserModel.new("Alice", profile)

    # Presenting form
    presented = UserTwin.from_object(user)
    assert_equal "Alice", presented.name
    assert_equal "Old bio", presented.profile.bio
    assert_equal "old@example.com", presented.profile.contact.email

    # Submitting form with nested changes on the same presented instance
    presented.assign_params({
      name: "Bob",
      profile: {
        bio: "New bio",
        contact: { email: "new@example.com" }
      }
    })

    assert presented.sync(nil) # defaults to stored model when available

    # Deep sync updates nested objects in place
    assert_equal "Bob", user.name
    assert_same profile, user.profile
    assert_equal "New bio", user.profile.bio
    assert_same contact, user.profile.contact
    assert_equal "new@example.com", user.profile.contact.email
  end

  test "sync falls back to writer with hashes when no nested target exists" do
    # Model without nested object instance yet
    user = UserModel.new("Carol", nil)

    twin = UserTwin.from_params({
      name: "Dave",
      profile: { bio: "Bio", contact: { email: "contact@example.com" } }
    })

    # The writer should receive a hash for profile
    assert twin.sync(user, validate: false)
    assert_equal "Dave", user.name
    assert user.profile.is_a?(Hash), "expected profile to be assigned as a Hash when no nested target exists"
    assert_equal({ bio: "Bio", contact: { email: "contact@example.com" } }.with_indifferent_access, user.profile)
  end
end
