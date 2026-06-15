# frozen_string_literal: true

require "rake/testtask"

load "lib/tasks/minitwin.rake"

Rake::TestTask.new(:test) do |t|
  t.libs << "lib"
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = false
end

task default: :test
