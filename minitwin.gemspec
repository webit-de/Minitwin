# frozen_string_literal: true

require_relative "lib/minitwin/version"

Gem::Specification.new do |spec|
  spec.name = "minitwin"
  spec.version = Minitwin::VERSION
  spec.authors = ["Johannes Balk", "Roland Schwarzer"]
  spec.email = ["eteam@webit.de"]
  spec.homepage = "https://www.webit.de"
  spec.license = "MIT"

  spec.summary = "Tiny presenter/twin"
  spec.description =
    "A minimal twin/presenter object with nested/collection properties, optional type coercion, and optional ActiveModel validations."

  spec.required_ruby_version = ">= 3.3"

  spec.files = Dir["lib/**/*", "README.md", "USAGE.md", "LICENSE*"].select { |f| File.file?(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "zeitwerk", ">= 2.6"
end
