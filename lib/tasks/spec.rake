# frozen_string_literal: true

return if Rails.env.production?

namespace :spec do
  desc 'glimmer | RSpec | Run unit tests'
  RSpec::Core::RakeTask.new(:unit, :rspec_opts) do |t, args|
    require_test_level
    t.pattern = Quality::TestLevel.new.pattern(:unit)
    t.rspec_opts = args[:rspec_opts]
  end

  desc 'glimmer | RSpec | Run integration tests'
  RSpec::Core::RakeTask.new(:integration, :rspec_opts) do |t, args|
    require_test_level
    t.pattern = Quality::TestLevel.new.pattern(:integration)
    t.rspec_opts = args[:rspec_opts]
  end

  desc 'glimmer | RSpec | Run system tests'
  RSpec::Core::RakeTask.new(:system, :rspec_opts) do |t, args|
    require_test_level
    t.pattern = Quality::TestLevel.new.pattern(:system)
    t.rspec_opts = args[:rspec_opts]
  end

  desc 'Run the code examples in spec/requests/api'
  RSpec::Core::RakeTask.new(:api) do |t|
    t.pattern = 'spec/requests/api/**/*_spec.rb'
  end

  def require_test_level
    require_relative '../../tooling/quality/test_level'
  end
end
