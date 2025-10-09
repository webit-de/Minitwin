require "test_helper"
require "mini_twin"

# Simulate an ActiveRecord-like model where `attributes` does not include
# association objects, but readers exist for them (has_one).
class ARLikeProfile
  def initialize(name:)
    @name = name
  end

  def attributes
    { name: @name }
  end
end

class ARLikeUser
  def initialize(id: 1, profile: nil)
    @id = id
    @profile = profile
  end

  def attributes
    { id: @id } # Note: no :profile key here, like ActiveRecord attributes
  end

  def profile
    @profile
  end
end

class UserWithHasOneTwin < MiniTwin
  property :id, type: Types::Params::Integer.lax
  property :profile do
    property :name
  end
end

class FromObjectHasOneTest < ActiveSupport::TestCase
  test "from_object populates block property from has_one reader when not in attributes" do
    user = ARLikeUser.new(id: 7, profile: ARLikeProfile.new(name: "Dana"))
    twin = UserWithHasOneTwin.from_object(user)
    assert_equal 7, twin.id
    assert twin.profile, "expected nested twin to be present"
    assert_equal "Dana", twin.profile.name
  end
end

