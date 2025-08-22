mini-twin
=========

A tiny “twin/presenter” with a small DSL to define properties, nested blocks, collections, light type coercion via dry-types, and optional ActiveModel validations. It’s designed to be framework-friendly but not framework-bound.

- Ruby: >= 3.4
- Runtime deps: dry-types, activesupport, activemodel (optional but enables validations)

Installation
------------

Add to your Gemfile:

`gem "mini-twin", github: "your-org/mini-twin"`

Or build and install locally:

`gem build mini-twin.gemspec && gem install mini-twin-*.gem`

Quick Start
-----------

```
require "mini_twin"

class AddressTwin < MiniTwin
  property :street
  property :city
end

class UserTwin < MiniTwin
  property :id, type: Types::Params::Integer.lax
  property :name, validates: { presence: true }
  property :active, type: Types::Params::Bool.lax
  property :profile do
    property :bio
  end
  collection :tags
  property :address, twin: AddressTwin
end

user = UserTwin.from_hash(
  id: "42",
  name: "Alex",
  active: "1",
  profile: { bio: "Builder of tiny things" },
  tags: %w[ruby gems],
  address: { street: "123 Ruby St", city: "Sinatra" }
)

user.id    #=> 42 (coerced)
user.active #=> true (coerced)
user.profile.bio #=> "Builder of tiny things"
user.address.city #=> "Sinatra"
user.to_hash #=> ActiveSupport::HashWithIndifferentAccess
```

DSL Reference
-------------

- property
  - Options: `as:`, `default:`, `virtual:`, `type:`, `getter: -> { ... }`, `setter: ->(value) { ... }`, `twin:`, `on:` (composition)
  - Block form creates a nested twin class.
- collection
  - Options: `as:`, `default: []`, `getter:`, `twin:`, `on:`
  - Also defines Rails-style `name_attributes` getter/setter aliases.

Types are provided via `Types` from dry-types:

`property :count, type: Types::Params::Integer.lax`
`property :enabled, type: Types::Params::Bool.lax`

Composition (on:)
-----------------

```
class OrderTwin < MiniTwin
  property :id, on: :order
  property :customer_name, on: :customer, as: :name
end

order = Data.define(:id).new(id: 7)
customer = Data.define(:customer_name).new(customer_name: "Dana")
obj = OrderTwin.from_objects(order:, customer:)
obj.id   #=> 7
obj.name #=> "Dana"
```

Assignment helpers
------------------

- assign_hash(Hash)
- assign_params(ActionController::Parameters)
- assign_object(Object)

Serialization
-------------

- to_hash(render_nil: false) → ActiveSupport::HashWithIndifferentAccess (if AS is available)
- to_h alias
- to_json forwards to `to_hash.to_json`

Virtual properties are omitted from `to_hash`.

Validations
-----------

When ActiveModel is available, validations declared in the DSL are enforced:

`property :name, validates: { presence: true }`

Nested blocks and collections propagate validation errors into the parent twin with dot/bracket paths.

Using Without ActiveModel
-------------------------

ActiveModel is optional. If it is not installed:

- Validation DSL calls are ignored (no `validates` method is available).
- Calling `valid?` on a twin returns `true` and does not collect errors.
- All other features (properties, collections, nested twins, type coercion, serialization, assignment) work as usual.

Development
-----------

- Run tests: `bundle exec rake test`
- Ruby version: `>= 3.4`

Project Layout
--------------

- lib/mini_twin.rb – loader and wiring
- lib/mini_twin/version.rb – version constant
- lib/mini_twin/types.rb – dry-types integration
- lib/mini_twin/initialization.rb – instance setup and helpers
- lib/mini_twin/assignment.rb – assignment helpers
- lib/mini_twin/serialization.rb – to_hash/to_json/valid?/attributes
- lib/mini_twin/class_methods.rb – class DSL and constructors

License
-------

MIT
