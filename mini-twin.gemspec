require_relative "lib/mini_twin/version"

Gem::Specification.new do |spec|
  spec.name          = "mini-twin"
  spec.version       = MiniTwin::VERSION
  spec.authors       = ["MiniTwin Maintainers"]
  spec.email         = ["devnull@example.com"]

  spec.summary       = "Tiny presenter/twin with ActiveModel-style validations"
  spec.description   = "A minimal twin/presenter object with nested/collection properties, type coercion via dry-types, and optional ActiveModel validations."
  spec.homepage      = "https://example.com/mini-twin"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 3.4"

  spec.files = Dir["lib/**/*", "README.md", "LICENSE*"].select { |f| File.file?(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "dry-types", ">= 1.7"
  spec.add_dependency "activesupport", ">= 6.1"

  # Development/test dependencies
  spec.add_development_dependency "rake", ">= 13.0"
  spec.add_development_dependency "minitest", ">= 5.18"
  spec.add_development_dependency "shoulda-context", ">= 2.0"
  spec.add_development_dependency "actionpack", ">= 6.1"
  spec.add_development_dependency "activemodel", ">= 6.1"
end
