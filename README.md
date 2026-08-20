# Minitwin

<img src="logo.png" alt="Minitwin Logo" width="20%">

## What is Minitwin?

It is a tiny presentation layer with a small DSL to define properties, collections, light type coercion via dry-types, and optional ActiveModel validations. It's designed to be framework-friendly but not framework-bound.


## Dependencies

- **Ruby** `>= 3.3`
- **[dry-types](https://dry-rb.org/gems/dry-types)** _(optional)_ — enables the `type:` coercion option on properties
- **[activesupport](https://github.com/rails/rails/tree/main/activesupport)** _(optional)_ — `to_hash` returns `HashWithIndifferentAccess` when available, otherwise a plain Hash
- **[activemodel](https://github.com/rails/rails/tree/main/activemodel)** _(optional)_ — enables the `validates:` DSL and `valid?`; without it, twins are always considered valid


## Getting Started

Add to your Gemfile:

`gem "minitwin"`

Or build and install locally:

`gem build minitwin.gemspec && gem install minitwin-*.gem`

Then define your first Twin:

```ruby
class UserTwin < Minitwin
  property :id, type: Types::Params::Integer.lax
  property :name, validates: { presence: true }
  property :active, type: Types::Params::Bool.lax
end

user = UserTwin.new(
  id: "42",
  name: "Alex",
  active: "1"
)
user.id     #=> 42 (coerced)
user.name   #=> "Alex"
user.active #=> true (coerced)

user.to_json
#=> '{"id":42,"name":"Alex","active":true}'
```

See [USAGE](./USAGE.md) for further examples.


## RBS

Minitwin comes with basic RBS signature files for its public interface. If you want to use them in
your project, you have to declare the dependency explicitly in your `rbs_collection.yaml` like so:

```yaml
  gems:
    - name: minitwin
```

Furthermore, Minitwin ships with a rake task, which generates the RBS signature files for all your
classes inheriting from `Minitwin`.

If you use Rails, the task is automatically loaded. Just run:
```bash
rails minitwin:generate_rbs
```

If you work with plain Ruby, you have to load the task in your `Rakefile`:

```ruby
load Gem.find_files("tasks/minitwin.rake").first
```

Then run the task:
```bash
rake minitwin:generate_rbs
```

By default, the task will output the rbs files in `sig/generated/`. You can adjust this by setting
a task argument or an ENV var `MINITWIN_RBS_DIR`. If both is set, the argument will be used.

```bash
rake minitwin:generate_rbs[sig/custom_path]

MINITWIN_RBS_DIR=sig/custom_path rake minitwin:generate_rbs
```


## Inspiration

Minitwin was inspired by [Disposable](https://github.com/apotonick/disposable).


## License

Minitwin is licensed under the MIT License. See [LICENSE](./LICENSE) for more details.
