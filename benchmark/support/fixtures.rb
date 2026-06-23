# frozen_string_literal: true

require "ostruct"

# Shared fixtures for the benchmark suite: one logical "User" record expressed
# as a symbol-keyed hash, a string-keyed hash, and four backing object types.
module Bench
  SRC_SYM = {
    id: "42", name: "Alex", active: "1",
    address: { city: "Berlin", zip: "10115" },
    roles: %w[admin editor]
  }.freeze

  SRC_STR = {
    "id" => "42", "name" => "Alex", "active" => "1",
    "address" => { "city" => "Berlin", "zip" => "10115" },
    "roles" => %w[admin editor]
  }.freeze

  INVALID_SYM = SRC_SYM.merge(name: "").freeze

  AddrData   = Data.define(:city, :zip)
  UserData   = Data.define(:id, :name, :active, :address, :roles)
  AddrStruct = Struct.new(:city, :zip)
  UserStruct = Struct.new(:id, :name, :active, :address, :roles)

  class PlainAddr
    attr_accessor :city, :zip

    def initialize(city:, zip:)
      @city = city
      @zip  = zip
    end

    def to_h = { city: city, zip: zip }
  end

  class PlainUser
    attr_accessor :id, :name, :active, :address, :roles

    def initialize(id:, name:, active:, address:, roles:)
      @id = id; @name = name; @active = active; @address = address; @roles = roles
    end

    def to_h = { id: id, name: name, active: active, address: address.to_h, roles: roles }
  end

  module_function

  def ostruct_user
    OpenStruct.new(id: SRC_SYM[:id], name: SRC_SYM[:name], active: SRC_SYM[:active],
                   address: OpenStruct.new(SRC_SYM[:address]), roles: SRC_SYM[:roles].dup)
  end

  def data_user
    UserData.new(id: SRC_SYM[:id], name: SRC_SYM[:name], active: SRC_SYM[:active],
                 address: AddrData.new(**SRC_SYM[:address]), roles: SRC_SYM[:roles].dup)
  end

  def struct_user
    UserStruct.new(SRC_SYM[:id], SRC_SYM[:name], SRC_SYM[:active],
                   AddrStruct.new(*SRC_SYM[:address].values), SRC_SYM[:roles].dup)
  end

  def plain_user
    PlainUser.new(id: SRC_SYM[:id], name: SRC_SYM[:name], active: SRC_SYM[:active],
                  address: PlainAddr.new(**SRC_SYM[:address]), roles: SRC_SYM[:roles].dup)
  end

  def backing_objects
    { "OpenStruct" => ostruct_user, "Data" => data_user,
      "Struct" => struct_user, "PlainClass" => plain_user }
  end
end
