# Usage

- [Basic](#basic)
- [Block properties](#block-properties)
- [Collection properties](#collection-properties)
- [Nested properties](#nested-properties)
- [Aliases](#aliases)
- [Coercion](#coercion)
- [Validations](#validations)
- [Working with objects](#working-with-objects)
- [Composition](#composition)
- [Round-tripping](#round-tripping)
- [DSL Reference](#dsl-reference)
- [Public Interface](#public-interface)

## Basic

Define properties and instantiate a twin, which can be serialized:

```ruby
class ArticleTwin < Minitwin
  property :title
  property :published
end

article = ArticleTwin.new(title: "Hello", published: true)
article.title      #=> "Hello"
article.published  #=> true

article.to_hash    #=> { title: "Hello", published: true }
article.to_json    #=> '{"title":"Hello","published":true}'
```

It's also possible to instantiate a twin from a plain Ruby Hash or JSON string:

```ruby
article = ArticleTwin.from_hash({title: "Hello", published: true})
article.title #=> "Hello"

json_string = { title: "Hello", published: true }.to_json
article = ArticleTwin.from_json(json_string)
article.title #=> "Hello"
```

## Block properties

A block creates an anonymous nested twin class for the property:

```ruby
class PostTwin < Minitwin
  property :title
  property :author do
    property :name
    property :email
  end
end

post = PostTwin.new(title: "Hi", author: { name: "Ana", email: "ana@example.com" })
post.author.name   #=> "Ana"
post.to_hash       #=> { title: "Hi", author: { name: "Ana", email: "ana@example.com" } }
```

Use `twin:` to reference an existing twin class instead of defining an inline block:

```ruby
class AddressTwin < Minitwin
  property :city
end

class UserTwin < Minitwin
  property :name
  property :address, twin: AddressTwin
end

user = UserTwin.new(name: "Bob", address: { city: "Berlin" })
user.address.city  #=> "Berlin"
```

To lift a value out of a nested twin into a top-level property, see
[Flattening a nested twin](#flattening-a-nested-twin).

## Collection properties

`collection` defines an array property. Each element can be a plain value or a nested twin:

```ruby
class InvoiceTwin < Minitwin
  collection :tags
end

inv = InvoiceTwin.new(tags: %w[urgent vip])
inv.tags  #=> ["urgent", "vip"]
```

With a block, each element becomes a twin instance:

```ruby
class OrderTwin < Minitwin
  collection :lines do
    property :product
    property :qty
  end
end

order = OrderTwin.new(lines: [
  { product: "Mug", qty: 2 },
  { product: "Shirt", qty: 1 }
])
order.lines.first.product  #=> "Mug"
order.to_hash
#=> { lines: [{ product: "Mug", qty: 2 }, { product: "Shirt", qty: 1 }] }
```

## Nested properties

`nested` groups properties under a container key in serialization while keeping a flat write API on the parent:

```ruby
class ProfileTwin < Minitwin
  property :username
  nested :settings do
    property :theme
    property :locale
  end
end

t = ProfileTwin.new(username: "dana", theme: "dark", locale: "en")
t.theme     #=> "dark"
t.to_hash   #=> { username: "dana", settings: { theme: "dark", locale: "en" } }
```

`nested` also accepts `as:` to rename the container key in serialization, the same
way `property` does. Because the block uses the plain `name` internally, the alias
may be any symbol — even one that is not a valid method or instance variable name:

```ruby
nested :settings, as: :"app:settings" do
  property :theme
end
#=> { :"app:settings" => { theme: "dark" } }
```

## Aliases

A static alias (symbol) renames the public getter and protects the original name. The serialized key follows the alias:

```ruby
class TokenTwin < Minitwin
  property :internal_token, as: :token
end

t = TokenTwin.new(internal_token: "abc")
t.token    #=> "abc"
t.to_hash  #=> { token: "abc" }
```

A dynamic alias (lambda) is evaluated per instance, so the public name can depend on other attributes:

```ruby
class FieldTwin < Minitwin
  property :key
  property :value, as: -> { key }
end

t = FieldTwin.new(key: "score", value: 42)
t.score    #=> 42
t.to_hash  #=> { key: "score", score: 42 }

t.key   = "total"
t.value = 99
t.total    #=> 99
t.to_hash  #=> { key: "total", total: 99 }
```

The lambda runs in instance context, so any reader on the twin is available. `as:` works the same way on `collection`.

## Coercion

Use `type:` with dry-types to coerce values on assignment. Coercion errors fall back to the raw value instead of raising:

```ruby
class EventTwin < Minitwin
  property :visitor_count, type: Types::Params::Integer.lax
  property :active,        type: Types::Params::Bool.lax
end

ev = EventTwin.new(visitor_count: "42", active: "1")
ev.visitor_count  #=> 42
ev.active         #=> true
```

## Validations

When ActiveModel is available, pass `validates:` to apply validations. Errors from nested twins and collections are aggregated on the parent:

```ruby
class ContactTwin < Minitwin
  property :email, validates: { presence: true, format: { with: URI::MailTo::EMAIL_REGEXP } }
  property :name,  validates: { presence: true }
end

c = ContactTwin.new(email: "", name: "")
c.valid?           #=> false
c.errors.full_messages
#=> ["Email can't be blank", "Email is invalid", "Name can't be blank"]
```

Validations propagate from nested twins:

```ruby
class RegistrationTwin < Minitwin
  property :contact do
    property :email, validates: { presence: true }
  end
end

r = RegistrationTwin.new(contact: { email: "" })
r.valid?  #=> false
r.errors.full_messages  #=> ["contact.email can't be blank"]
```

## Working with objects

`from_object` reads attributes from any object with `attributes`, `to_h`, or readers:

```ruby
class UserTwin < Minitwin
  property :name
  property :email
end

User = Data.define(:name, :email)
user = UserTwin.from_object(User.new(name: "Alex", email: "alex@example.com"))
user.name  #=> "Alex"
```

`assign_hash` updates an existing twin in place (only known attributes):

```ruby
twin = UserTwin.new(name: "Alex", email: "old@example.com")
twin.assign_hash(email: "new@example.com")
twin.email  #=> "new@example.com"
```

`sync` writes values back to the original model. It uses the stored reference from `from_object`, so no argument is needed:

```ruby
class ItemTwin < Minitwin
  property :name
  property :price
end

class Item
  attr_accessor :name, :price

  def initialize(name:, price:)
    @name  = name
    @price = price
  end
end

item = Item.new(name: "Book", price: 10)
twin = ItemTwin.from_object(item)

twin.price = 20
twin.sync    #=> true

item.price   #=> 20
```

## Composition

Use `on:` to read a property from a specific source object instead of storing the value on the twin itself:

```ruby
class SummaryTwin < Minitwin
  property :id,    on: :order
  property :total, on: :order
  property :name,  on: :customer
end

Order    = Data.define(:id, :total)
Customer = Data.define(:name)

summary = SummaryTwin.from_objects(
  order:    Order.new(id: 7, total: 99.0),
  customer: Customer.new(name: "Dana")
)
summary.id     #=> 7
summary.name   #=> "Dana"
```

### Flattening a nested twin

Use `on:` to read a property from a nested twin instead of a `from_objects` source: a symbol falls
back to a reader on the twin itself, and a lambda runs in instance context and returns any object
reachable from it. The nested structure is flattened into top-level properties:

```ruby
class SiteTwin < Minitwin
  property :address, expose: false do
    property :city
    property :installation do
      property :street
    end
  end

  property :city,   on: :address                    # one level: a symbol is enough
  property :street, on: -> { address.installation }  # deeper path: use a lambda
end

site = SiteTwin.new(
  address: { city: "Berlin", installation: { street: "1234 fake street" } }
)
site.city    #=> "Berlin"
site.street  #=> "1234 fake street"
site.to_hash #=> { city: "Berlin", street: "1234 fake street" }
```

The property name is the reader called on the source: `city` is read as `address.city`. When the names
differ, or when a link in the path may be `nil`, use `getter:` instead — `property :town, getter: -> { address.city }`
or `getter: -> { address&.installation&.street }`.

The flattening only works for reading: `site.city = "Hamburg"` is discarded, so assign to
`site.address.city` instead.

## Round-tripping

Talking to an API usually means two conversions: your own model has to become a request
payload, and the response has to become your own model again. Use **one twin per
direction** — a request twin that serializes, and a response twin that deserializes.

The request twin is written from your side: the property names are your model's attribute
names (so `from_object` can read them), and `as:` supplies the names the API expects:

```ruby
class SubscriptionRequestTwin < Minitwin
  property :plan
  property :seats,      as: :seat_count,      type: Types::Params::Integer.lax
  property :start_date, as: :activation_date, type: Types::Params::Date.lax
end

subscription = Subscription.new(plan: "pro", seats: "3", start_date: "2026-01-01")

request = SubscriptionRequestTwin.from_object(subscription)
request.to_json
#=> '{"plan":"pro","seat_count":3,"activation_date":"2026-01-01"}'
```

The response twin is written from the API's side: the property names are the keys the API
sends (so `from_json`/`from_hash` can pick them up), and `as:` maps them back onto your own
vocabulary — which is also the name `sync` writes to on the model:

```ruby
class SubscriptionResponseTwin < Minitwin
  property :id,              as: :remote_id
  property :status
  property :seat_count,      as: :seats,      type: Types::Params::Integer.lax
  property :activation_date, as: :start_date, type: Types::Params::Date.lax
end

response = SubscriptionResponseTwin.from_json(api_response_body)
response.remote_id   #=> "sub_1"
response.seats       #=> 5
response.start_date  #=> #<Date: 2026-02-01>

response.sync(subscription)
subscription.remote_id   #=> "sub_1"
subscription.seats       #=> 5
subscription.start_date  #=> #<Date: 2026-02-01>
```

Both twins declare the same mapping, just from opposite ends. Coercion happens on both
legs, so the payload carries a real `Integer` and the model receives a real `Date` — even
though the wire format is a string in both cases.

### Why two twins and not one?

Reusing a single twin for both legs looks tempting: the mapping is the same, so why declare
it twice? Because a twin is a *directed* mapping, not a bidirectional schema. Its structure
is already asymmetric:

- **Input keys** are the property names (the generated setters), so a hash is read using the
  original names.
- **Output keys** follow `as:`, and `as:` also protects the original name — so what
  `to_hash` writes is deliberately not what `from_hash` accepts.

More importantly, the interesting parts of a mapping cannot be inverted automatically:

- **Type coercion is one-way.** `Types::Params::Integer.lax` turns `"3"` into `3`, but
  nothing says whether the reverse should be `"3"`, `"3.0"`, or `3`. And because coercion
  errors fall back to the raw value, the same type can even be a no-op for some inputs —
  there is no function to invert.
- **Dynamic `as:` aliases depend on the instance.** `property :value, as: -> { key }` names
  the output key from another attribute. Going backwards would mean guessing which incoming
  key was produced by that lambda before the twin exists to evaluate it.
- **`getter:`/`setter:` lambdas are opaque.** They are arbitrary Ruby, so a getter that
  joins, formats, or derives a value gives no way to compute the inverse. A `setter:` that
  normalizes input cannot be run backwards to recover what came in.

So instead of one twin trying to be reversible, write each direction explicitly. Two small
twins are cheap, they document the API contract twice from the two perspectives that matter,
and each one keeps the coercions and defaults appropriate for its own direction — the
outbound payload and the inbound response often differ anyway (the response carries an `id`
and a `status` the request never sends).

---

## DSL Reference

### `property`

| Option | Description |
|---|---|
| `as:` | Public getter name. Protects the original name. Accepts a symbol or a lambda `-> { ... }` for dynamic aliases computed per instance. |
| `default:` | Default value when the property is `nil`. Accepts a callable (`-> { ... }`) for computed defaults. |
| `type:` | A dry-types type for coercion on assignment (e.g. `Types::Params::Integer.lax`). Errors fall back to the raw value. |
| `twin:` | Wraps the value in another twin class. Accepts a hash, a twin instance, or an object with `to_h`/`attributes`. |
| `expose:` | `false` omits the property from `to_hash`/`to_json`. |
| `readonly:` | `true` prevents assignment via `assign_hash` and `assign_params`. |
| `getter:` | A lambda `-> { ... }` or a symbol `:method_name` that fully replaces the generated getter. The lambda runs in instance context; the symbol calls the named method on the instance. If the lambda or method accepts a parameter, the current raw property value is passed as the argument. |
| `setter:` | A lambda `->(value) { ... }` that fully replaces the generated setter. Not allowed together with a block. |
| `on:` | Reads the value from a composition source (see `from_objects`), which can also be a nested twin. Accepts a symbol or a lambda `-> { ... }` returning the source. |
| `validates:` | ActiveModel validation options, e.g. `{ presence: true }`. Ignored when ActiveModel is not available. |
| block | Defines an inline nested twin class. Mutually exclusive with `setter:`. |

### `collection`

| Option | Description |
|---|---|
| `as:` | Public getter name. Accepts a symbol or a lambda `-> { ... }` for dynamic aliases. |
| `default:` | Default value. Defaults to `[]`. |
| `twin:` | Wraps each element in the given twin class. |
| `getter:` | A lambda `-> { ... }` or a symbol `:method_name` that fully replaces the generated getter. The lambda runs in instance context; the symbol calls the named method on the instance. If the lambda or method accepts a parameter, the current raw property value is passed as the argument. |
| `on:` | Reads the collection from a composition source, which can also be a nested twin. Accepts a symbol or a lambda `-> { ... }`. Each element is wrapped in the element twin when one is configured. |
| `validates:` | ActiveModel validation options applied to the collection property itself. |
| block | Defines an inline nested twin class used for each element. |

### `nested`

Groups properties under a container key in serialization while keeping a flat read/write API on the parent twin. Requires a block.

```ruby
nested :address do
  property :city
  property :zip
end
```

The leaf properties (`city`, `zip`) are accessible directly on the parent instance. `to_hash` places them under the `address` key.

| Option | Description |
|---|---|
| block | Required. Defines the nested twin class. |
| `as:` | Renames the container key in serialization. Accepts any symbol, including one that is not a valid identifier. |

---

## Public Interface

### Class methods

**Constructors**

| Method | Description |
|---|---|
| `from_hash(hash)` | Instantiates a twin from a plain Ruby Hash. |
| `from_json(string)` | Parses a JSON string and delegates to `from_hash`. |
| `from_params(params)` | Accepts `ActionController::Parameters` or a plain Hash. Unwraps `to_unsafe_h` automatically. |
| `from_object(model)` | Reads attributes from a single object via `attributes`, `to_h`, or readers. Stores the object for later `sync`. |
| `from_objects(**models)` | Merges attributes from multiple named objects. Last value wins on key conflicts. Stored objects are available as composition sources via `on:`. |
| `from_collection(array)` | Applies `from_objects` semantics to each element and returns an array of twins. |

**Other**

| Method | Description |
|---|---|
| `to_rbs` | Returns an RBS signature string for the twin class. |

---

### Instance methods

**Serialization**

| Method | Description |
|---|---|
| `to_hash(render_nil: false)` | Returns the twin as a Hash (or `HashWithIndifferentAccess` when ActiveSupport is available). Nested twins are serialized recursively. Unexposed properties are omitted. |
| `to_h` | Alias for `to_hash`. |
| `to_json` | Delegates to `to_hash.to_json`. |
| `attributes` | Returns a Hash keyed by the original setter names (before any `as:` aliasing). Includes protected readers. |
| `pretty_print(q)` | Integrates with Ruby's `pp` library. Outputs the twin with class name, properties in definition order, and nested twins recursively formatted with their own class names. |

**Validation**

| Method | Description |
|---|---|
| `valid?` | Returns `true` when all validations pass. Without ActiveModel, always returns `true`. Errors from nested twins and collections are aggregated with dot/bracket paths (e.g. `contact.email`, `lines[0].qty`). |

**Assignment**

| Method | Description |
|---|---|
| `assign_hash(hash)` | Updates known attributes in place from a Hash. Recurses into nested twins and collection elements. |
| `assign_params(params)` | Like `assign_hash`, but also accepts `ActionController::Parameters`. |
| `assign_object(model)` | Copies matching attributes from an object via its readers and stores the object for later `sync`. |
| `to_object(model)` | Mirrors the twin's values into an existing model via its writers. Does not store the model. |

**Sync**

| Method | Description |
|---|---|
| `sync(model = nil, validate: true)` | Writes the twin's values back to the model. When `model` is omitted, uses the object stored by `from_object`/`assign_object`. Returns `false` when validation fails or no model is available. Recurses into nested twins and collection elements. |

**Introspection**

| Method | Description |
|---|---|
| `dynamic_aliases` | Returns a Hash of `alias_name => target_method` for all dynamic aliases active on the current instance. |
