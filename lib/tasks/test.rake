# frozen_string_literal: true

Rake::Task["test"].clear

desc "glimmer | Run all tests"
task :test do
  Rake::Task["glimmer:test"].invoke
end
