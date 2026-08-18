# frozen_string_literal: true

require_relative "lib/minitwin/version"

Gem::Specification.new do |spec|
  spec.name = "minitwin"
  spec.version = Minitwin::VERSION
  spec.authors = ["Johannes Balk", "Roland Schwarzer", "Susanne Götze", "Leon Stöckert"]
  spec.email = ["balk@webit.de", "schwarzer@webit.de", "susanne.goetze@webit.de", "leon.stoeckert@webit.de"]
  spec.homepage = "https://github.com/webit-de/minitwin"
  spec.license = "MIT"

  spec.summary = "Minimal presentation layer"
  spec.description =
    "It is a tiny presentation layer with a small DSL to define properties, " \
      "collections, light type coercion via dry-types, and optional ActiveModel validations. " \
      "It's designed to be framework-friendly but not framework-bound."

  spec.required_ruby_version = ">= 3.3"

  spec.files = Dir["lib/**/*", "sig/**/*", "rbi/**/*", "README.md", "USAGE.md", "LICENSE*"].select { |f| File.file?(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "zeitwerk", ">= 2.6"
end
