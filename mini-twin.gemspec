require_relative "lib/mini_twin/version"

Gem::Specification.new do |spec|
  spec.name = "mini-twin"
  spec.version = Minitwin::VERSION
  spec.authors = [ 'Johannes Balk', 'Roland Schwarzer' ]
  spec.email = [ 'eteam@webit.de' ]
  spec.homepage = 'https://www.webit.de'

  spec.summary = "Tiny presenter/twin"
  spec.description = "A minimal twin/presenter object with nested/collection properties, optional type coercion, and optional ActiveModel validations."

  spec.required_ruby_version = ">= 3.3"

  spec.files = Dir["lib/**/*", "README.md", "LICENSE*"].select { |f| File.file?(f) }
  spec.require_paths = [ "lib" ]

  # Runtime dependencies
  spec.add_dependency "zeitwerk", ">= 2.6"

  # Development/test dependencies
  spec.add_development_dependency "dry-types", ">= 1.7"
  spec.add_development_dependency "rake", ">= 13.0"
  spec.add_development_dependency "minitest", ">= 5.18"
  spec.add_development_dependency "m", ">= 1.6"
  spec.add_development_dependency "actionpack", ">= 6.1"
  spec.add_development_dependency "activemodel", ">= 6.1"
  spec.add_development_dependency "simplecov", ">= 0.22"
end
