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
- nested
  - Usage: `nested :container do ... end`
  - Groups inner properties under a container key in serialization while exposing them as top-level setters/getters on the parent.
  - Inner properties are omitted at the top level in `to_hash`/`to_json` and appear only under the container.
  - Supports deeper nesting via nested blocks within the group.

Notes:
- The DSL methods (`property`, `collection`, `nested`) are private class methods intended for use inside twin class bodies (e.g., `class MyTwin < MiniTwin; property :x; end`). They are not part of the public class API and aren’t callable as `MyTwin.property` from the outside.

Public Class API
----------------

The following class methods are public and supported:

- `from_hash`, `from_json`, `from_params`
- `from_object`, `from_objects`, `from_collection`
- `to_rbs` (RBS generation for the class)

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

Notes on collections with `on:`:
- When a `collection` is defined with `on: :source`, the getter wraps each raw element coming from the source into the configured element twin (either the block-defined twin or the `twin:` class). This ensures aliases (`as:`), nested properties, and validations behave as expected when reading from composed objects.
- Example:

```
class ContractTwin < MiniTwin
  collection :items, on: :contract do
    property :sub, as: :renamed
  end
end

contract = Data.define(:items).new(items: [ Data.define(:sub).new(sub: "x") ])
t = ContractTwin.from_objects(contract: contract)
t.items.first.renamed #=> "x"  # element is a twin instance
```

- Elements without `to_h`/`attributes` (e.g., plain Ruby or ActiveModel objects) are also supported: the getter reflects values using the element twin's property names (falling back to instance variables) and instantiates element twins accordingly.
 - Elements without `to_h`/`attributes` (e.g., plain Ruby or ActiveModel objects) are also supported: the getter reflects values using the element twin's property names (falling back to instance variables) and instantiates element twins accordingly.
 - For has_many relations (e.g., ActiveRecord CollectionProxy), the getter treats any array-like value that responds to `to_a` as a list and wraps each element into the element twin. The raw relation object is not exposed to callers.

Assignment helpers
------------------

- assign_hash(Hash)
- assign_params(ActionController::Parameters)
- assign_object(Object)

Notes for `assign_object`:
- Uses the twin's defined setter names to copy values, so attributes aliased via `as:` are populated correctly.
- For collections defined with a block or `twin:`, incoming elements are wrapped into the element twin, enabling aliased getters and nested behavior on read.

Example:

```
class AliasTwin < MiniTwin
  property :sub_property, as: :renamed
end

class AliasCollectionTwin < MiniTwin
  collection :items do
    property :sub_property, as: :renamed
  end
end

model1 = Data.define(:sub_property).new(sub_property: "x")
t1 = AliasTwin.new.assign_object(model1)
t1.renamed #=> "x"

elem = Data.define(:sub_property)
model2 = Data.define(:items).new(items: [ elem.new(sub_property: "a") ])
t2 = AliasCollectionTwin.new.assign_object(model2)
t2.items.first.renamed #=> "a"  # element is wrapped as a twin
```

Serialization
-------------

- to_hash(render_nil: false) → ActiveSupport::HashWithIndifferentAccess (if AS is available)
- to_h alias
- to_json forwards to `to_hash.to_json`
- attributes returns a Hash keyed by base setter names (original property names), even when public getters are aliased via `as:`.

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

RBS Types
---------

MiniTwin can generate RBS signatures for your twins so type checkers (e.g., Steep) know your attribute types.

- Types come from the DSL:
  - `type:` (Dry::Types) on a property determines its RBS type (e.g., `Types::Params::Integer.lax` → `Integer`, `Types::Params::Bool` → `bool`).
  - `twin:` or a nested block defines a nested twin class, which is referenced as the property type.
  - Collections become `Array[ElementType]`.

- Generate RBS on exit by setting an environment variable:

```
MINI_TWIN_RBS_OUT=sig/mini_twin_generated.rbs bundle exec rake test
```

This writes RBS for all loaded twins (with names) to `sig/mini_twin_generated.rbs`.

- Programmatic API:

```
class UserTwin < MiniTwin
  property :id, type: Types::Params::Integer.lax
  property :name
  property :profile do
    property :bio
  end
end

File.write("sig/user_twin.rbs", UserTwin.to_rbs)
```

Notes:
- Nested block twins are assigned a stable constant under the parent (e.g., `UserTwin::Profile`) to allow RBS to reference them.
- Properties without a `type:` are emitted as `untyped`.
- Aliased getters (`as:`) are reflected with the alias as reader and the original as writer.

Project Layout
--------------

- lib/mini_twin.rb – loader and wiring
- lib/mini_twin/version.rb – version constant
- lib/mini_twin/types.rb – dry-types integration
- lib/mini_twin/initialization.rb – instance setup and helpers
- lib/mini_twin/assignment.rb – assignment helpers
- lib/mini_twin/serialization.rb – to_hash/to_json/valid?/attributes
- lib/mini_twin/class_methods.rb – includes the following internal modules:
  - lib/mini_twin/class_methods/dsl.rb – DSL for `property`, `collection`, `nested`
  - lib/mini_twin/class_methods/constructors.rb – `from_*`, registries
  - lib/mini_twin/class_methods/rbs.rb – RBS generation helpers
  - lib/mini_twin/class_methods/caches.rb – small caches and invalidation
  - lib/mini_twin/class_methods/types_helper.rb – type defaults and coercion helpers

Design Overview
---------------

MiniTwin is a plain-Ruby, framework-light “twin” object. It exposes a simple DSL for defining:

- Properties: scalar or nested (via a block), with optional type coercion and validations.
- Collections: arrays of scalars or nested twins.
- Nested groups: group related properties under a container key while keeping a flat write API.
- Composition: map read access to external objects via `on:` without copying data.

At runtime, a twin is just a Ruby object with generated getters/setters. The modules under `lib/mini_twin` compose these responsibilities:

- `ClassMethods`: the DSL (`property`, `collection`) and constructors (`from_*`).
- `Initialization`: filters constructor args to known attributes, builds nested twins.
- `Assignment`: assign/update from objects, hashes, or params.
- `Serialization`: convert a twin back to a hash/JSON; aggregate validations.
- `Types`: `Dry::Types` integration via a convenient `Types` module.

How It Works
------------

- Defining properties
  - `property :name` defines a writer (`name=`) and a getter (`name`).
  - `as:` creates a public alias for the getter and protects the original name.
  - `type:` (Dry::Types) coerces on write; invalid coercions return the raw value.
  - `default:` is used when the getter returns `nil` or when not set via constructor.
  - Block form builds a nested anonymous twin class and wires `name=` to construct it.
  - `twin:` embeds another twin class, accepting a hash, an instance, or an object with `to_h`/`attributes`.

- Defining collections
  - `collection :items` behaves like an array; `items=` converts each element.
  - Block form or `twin:` ensures each element is a nested twin instance.
  - Adds Rails-style `items_attributes` getter/setter aliases for form helpers.

- Constructors
  - `from_hash`, `from_json`, `from_params(ActionController::Parameters)`,
    `from_object`, and `from_objects(order:, customer:)`.
  - `from_objects` merges attribute hashes from multiple sources; last one wins on key conflicts.
  - When composing via `on:`, the referenced external objects are stored internally and read on demand.
  - Enrichment: if a property or collection is missing OR has a `nil` value in a model's `attributes` hash, `from_objects` will attempt to populate it by calling a same-named reader on the provided models (even when the `attributes` hash contains the key set to `nil`). This covers typical ORM associations:
    - has_one: nested block/twin properties are initialized from the reader value.
    - has_many: collections accept relation proxies and normalize via `to_a`, wrapping elements into the configured element twin.
  - `from_collection` accepts arrays of hashes, objects with `to_h`/`attributes`, ActiveModel objects, or plain Ruby objects. It reuses `from_objects` semantics for each element, including alias handling and enrichment of missing/nil properties or collections from readers (has_one/has_many). For non-hash elements it reflects values by calling readers matching the element twin's properties (or instance variables) and instantiates the element twin.

- Assignment
  - `assign_hash` and `assign_params` update only known attributes.
  - Nested hashes update nested twins in place; collections update existing elements by index.
  - `assign_object` copies matching attributes from a plain object and stores it internally for composition.
  - `to_object(model)` copies values from a model’s getters into the twin via setters (for mirroring state).

- Serialization
  - `to_hash(render_nil: false)` returns a `HashWithIndifferentAccess` when ActiveSupport is present; otherwise a plain Hash.
  - Nested twins serialize recursively; arrays preserve elements and drop only `nil`.
  - Virtual properties are omitted.

- Validations
  - If ActiveModel is loaded, `validates:` options on properties are applied.
  - Errors from nested twins and collections are aggregated using dot/bracket notation (e.g., `duplo.brick`, `items[0].name`).
  - ActiveModel is optional; without it, twins are always considered valid.

Edge Cases & Behavior Notes
---------------------------

- Type coercion: Coercion errors (`Dry::Types::CoercionError`, `TypeError`, `ArgumentError`) fall back to the raw input instead of raising.
- `twin:` handling: accepts `nil`, a twin instance, a Hash, or an object with `attributes`/`to_h`. Arrays shaped like Rails param pairs (`["0", {...}]`) are also supported.
- Block properties: `prop = {}` initializes an empty nested twin; `prop = nil` clears it.
- Composition: When using `on:`, the source object must be available either via `from_objects(source: ...)` or via a reader method. A helpful error is raised if the source is missing.
- Aliases: When using `as:`, the original name is protected so only the alias is public. Predicate methods (`?`) are not double-aliased.
- Attributes export: `attributes` uses base setter names (e.g., `secret_value`) for keys and reads values even when the original reader is protected by aliasing.

Performance Notes
-----------------

- Reflection caching: Twins cache the list of serializable getters and allowed attribute keys to reduce reflection during `initialize` and `to_hash`. Caches are invalidated when new properties/collections are defined.

Contributing
------------

- Run tests: `bundle exec rake test`
- Coding style: keep changes minimal and focused; prefer improving core behavior over adding new surface area.
- Docs: see `docs/ARCHITECTURE.md` for internals.

Developer Notes
---------------

- Coercion helpers: Internally, conversion of incoming values into twins is centralized.
  - `coerce_value_to_twin(value, klass)`: Wraps hashes, ActiveModel objects (`attributes`), objects with `to_h`, Rails param-pair arrays (e.g., `["0", {...}]`), and plain objects (by reflecting property readers or instance variables) into `klass`.
  - `coerce_collection_array(raw)`: Treats any array-like (e.g., ActiveRecord `CollectionProxy`) as an array using `to_a`.
  - Used by: collection setters, block property setters, `twin:` property setters, and composition getters for collections.
  - Benefit: consistent behavior and fewer code paths to maintain.

- Enrichment on constructors: `from_objects` (and therefore `from_object` and `from_collection`) will populate missing or `nil` attributes by calling same-named readers on source objects. Collections normalize via `to_a`.

- Serialization: Uses cached `serializable_getters` to avoid repeated reflection. Virtual and protected readers are excluded; aliases are respected.

License
-------

Nested Grouping
----------------

Expose a clean input API while serializing under a nested key:

```
class ProfileTwin < MiniTwin
  nested :profile do
    property :bio
    property :website
  end
end

t = ProfileTwin.new(bio: "Hello", website: "https://example.com")
t.to_hash
#=> { profile: { bio: "Hello", website: "https://example.com" } }
```

Notes:
- You can nest groups: `nested :outer { property :a; nested :inner { property :b } }`.
- Top-level proxy methods for inner properties are virtual (not serialized at the top level).

MIT
