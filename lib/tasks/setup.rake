# frozen_string_literal: true

desc "glimmer | Setup glimmer db"
task :setup do
  Rake::Task["glimmer:setup"].invoke
end
