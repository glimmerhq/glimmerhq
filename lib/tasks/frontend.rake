# frozen_string_literal: true

unless Rails.env.production?
  namespace :frontend do
    desc 'glimmer | Frontend | Generate fixtures for JavaScript tests'
    RSpec::Core::RakeTask.new(:fixtures, [:pattern]) do |t, args|
      directories = %w[spec]
      directory_glob = "{#{directories.join(',')}}"
      args.with_defaults(pattern: "#{directory_glob}/frontend/fixtures/**/*.rb")
      ENV['NO_KNAPSACK'] = 'true'
      t.pattern = args[:pattern]
      t.rspec_opts = '--format documentation'
    end

    desc 'glimmer | Frontend | Run JavaScript tests'
    task tests: ['yarn:check'] do
      sh "yarn test" do |ok, res|
        abort('rake frontend:tests failed') unless ok
      end
    end
  end

  desc 'glimmer | Frontend | Shortcut for frontend:fixtures and frontend:tests'
  task frontend: ['frontend:fixtures', 'frontend:tests']
end
