# frozen_string_literal: true

unless Rails.env.production?
  namespace :karma do
    # alias exists for legacy reasons
    desc 'glimmer | Karma | Generate fixtures for JavaScript tests'
    task fixtures: ['frontend:fixtures']

    desc 'glimmer | Karma | Run JavaScript tests'
    task tests: ['yarn:check'] do
      sh "yarn run karma" do |ok, res|
        abort('rake karma:tests failed') unless ok
      end
    end
  end

  desc 'glimmer | Karma | Shortcut for karma:fixtures and karma:tests'
  task karma: ['karma:fixtures', 'karma:tests']
end
