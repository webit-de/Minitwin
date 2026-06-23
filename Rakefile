# frozen_string_literal: true

require "rake/testtask"
require "bundler/gem_tasks"

load "lib/tasks/minitwin.rake"

Rake::TestTask.new(:test) do |t|
  t.libs << "lib"
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = false
end

desc "Run the performance benchmark suite (minitwin vs disposable/representable/dry-struct)"
task :benchmark do
  require "fileutils"
  FileUtils.mkdir_p("benchmark/results")
  sh "ruby -Ilib benchmark/run_all.rb | tee benchmark/results/latest.txt"
end

task bench: :benchmark

task default: :test
