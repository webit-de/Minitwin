# frozen_string_literal: true

require "test_helper"
require "mini_twin"

class ToObjectNestedTest < ActiveSupport::TestCase
  Contact = Struct.new(:email)
  Profile = Struct.new(:bio, :contact)
  User = Struct.new(:name, :profile)

  class UserTwin < Minitwin
    property :name
    property :profile do
      property :bio
      property :contact do
        property :email
      end
    end
  end

  test "to_object mirrors nested models into nested twins" do
    contact = Contact.new("nested@example.com")
    profile = Profile.new("About me", contact)
    user = User.new("Alice", profile)

    twin = UserTwin.new
    twin.to_object(user)

    assert_equal "Alice", twin.name
    assert_instance_of UserTwin::Profile, twin.profile
    assert_equal "About me", twin.profile.bio
    assert_instance_of UserTwin::Profile::Contact, twin.profile.contact
    assert_equal "nested@example.com", twin.profile.contact.email
  end
end
