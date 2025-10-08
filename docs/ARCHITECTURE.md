MiniTwin Architecture
=====================

This document explains the internal structure of MiniTwin so new contributors can navigate and extend the code confidently.

Overview
--------

MiniTwin is a small DSL that builds plain Ruby objects with predictable behavior:

- Define attributes (properties/collections) and optional nested twins.
- Construct from hashes, JSON, Rails params, or objects.
- Assign/merge incoming data into an existing twin.
- Serialize back to a Hash/JSON.
- Optionally validate via ActiveModel and aggregate nested errors.

Files and Responsibilities
--------------------------

- `lib/mini_twin.rb`
  - Requires optional dependencies (ActiveModel) when available.
  - Loads the submodules and defines the `MiniTwin` class, mixing in the modules.
  - Includes `ActiveModel::Model` only if present, keeping the gem light.

- `lib/mini_twin/class_methods.rb`
  - Orchestrates class-level behavior by including internal modules:
    - `lib/mini_twin/class_methods/dsl.rb` — DSL for `property`, `collection`, `nested`, plus accessor generation.
    - `lib/mini_twin/class_methods/constructors.rb` — `from_*` constructors, attribute registries, composition wiring.
    - `lib/mini_twin/class_methods/rbs.rb` — RBS generation with type mapping.
    - `lib/mini_twin/class_methods/caches.rb` — method/capability caches and invalidation.
    - `lib/mini_twin/class_methods/types_helper.rb` — type defaulting and read-time coercion helpers.
  - Visibility: DSL methods are private class methods (usable in class bodies); constructors and `to_rbs` are public class methods.

- `lib/mini_twin/initialization.rb`
  - Filters `initialize(**args)` to known keys only.
  - Prepares defaults for nested block properties so empty hashes create empty nested twins.
  - Provides helpers to set instance variables and discover attribute methods.

- `lib/mini_twin/assignment.rb`
  - Updates a twin from an object (`assign_object`), a hash (`assign_hash`), or Rails params (`assign_params`).
  - Performs in-place updates of nested twins and collection items when possible.
  - `to_object(model)` mirrors values from a model’s getters to the twin’s setters defensively.

- `lib/mini_twin/serialization.rb`
  - Converts a twin to hash (`to_hash`/`to_h`) and JSON (`to_json`).
  - Omits virtual properties; nests recursively; arrays preserve elements and drop only `nil`.
  - Aggregates nested validation errors when ActiveModel validations are present.

- `lib/mini_twin/types.rb`
  - Exposes `Types` by including `Dry.Types()` for convenient type references.

Data Flow
---------

1) Definition time
   - `property(:name, ...)` creates a writer and a getter. Options influence coercion (read-time), defaults, aliases, nested behavior, and validations.
   - `collection(:items, ...)` creates an array-like attribute and Rails-style `items_attributes` aliases.
   - `nested(:container) { ... }` creates a block property (container) and defines proxy getter/setter methods on the parent for all leaf properties inside the group (including deeper nested groups). Proxies are marked virtual so they do not serialize at the top level.
   - Nested block form creates a new anonymous `MiniTwin` subclass for the child.

2) Construction
   - `from_hash`/`from_json`/`from_params` normalize inputs to a symbol-keyed hash and call `new(**args)`.
   - `Initialization#initialize` filters args to known attributes and seeds nested block properties with `{}` to construct empty children.
   - Setters apply type coercion (if configured) and instantiate nested twins.

3) Mutation
   - `assign_hash` updates only known attributes; nested twins and collections are updated in place when possible, by recursing into child twins and iterating by index.
   - `assign_object` copies matching methods from a source object and stores it internally for composition.
   - `assign_params` is just `assign_hash(params.to_unsafe_h)` when ActionPack is available.

4) Reading & Composition
   - Getters with `on:` read from an associated external object (set by `from_objects` or via an accessor). A clear error is raised if the source is missing.
   - `as:` creates a public alias for the getter and protects the original name, keeping external API clean.

5) Serialization
   - `to_hash` walks serializable getters (from cache) and builds a `HashWithIndifferentAccess` when ActiveSupport is available, otherwise a plain Hash.
   - Nested twins serialize recursively; arrays map elements and compact away only `nil` values.
   - Nested groups: only the container (e.g., `:profile`) is serialized; proxy methods for inner properties are virtual and omitted at the top level.

6) Validation
   - If ActiveModel is loaded, validations declared via `validates:` are applied.
   - Errors from nested twins and collections are aggregated into the parent using `duplo.brick` and `items[0].name` paths.

Key Behaviors and Edge Cases
----------------------------

- Type coercion: exceptions from Dry Types coercion return the uncoerced value (fail-soft) to avoid surprising runtime errors.
- Twin embedding: `twin:` setters accept `nil`, a twin instance, a Hash, or objects with `attributes`/`to_h`. Arrays shaped like Rails param pairs are supported.
- Defaults: `default:` acts at read time; getters fall back to the provided default when unset.
- Virtual properties: excluded from serialization.
- Nested groups: Proxy methods are added on the parent for convenience (flat write API). If a parent already defines a property with the same name as a proxy, the last definition wins (avoid name collisions in practice).
- Aliases: when `as:` is used, the original name is made `protected` to prevent accidental external calls. Predicate names (`?`) are not double-aliased.
 - Visibility: class DSL (`property`, `collection`, `nested`) is private to discourage external mutation of the class; construction and RBS APIs are public.

Performance
-----------

- Reflection caches reduce repeated scanning of methods in `initialize` and `to_hash`.
- The cache is simple and invalidated on each DSL mutation (defining a new property/collection).

Testing & Development
---------------------

- Run `bundle exec rake test`.
- Tests cover initialization/coercion, assignment, serialization, embedding, composition, params, JSON, and validations.
