# frozen_string_literal: true

unless Rails.env.production?
  namespace :lint do
    task :static_verification_env do
      ENV['STATIC_VERIFICATION'] = 'true'
    end

    desc "glimmer | Lint | Static verification"
    task static_verification: %w[
      lint:static_verification_env
      dev:load
    ] do
      Glimmer::Utils::Override.verify!
    end

    desc "glimmer | Lint | Lint JavaScript files using ESLint"
    task :javascript do
      Rake::Task['eslint'].invoke
    end

    desc "glimmer | Lint | Lint HAML files"
    task :haml do
      Rake::Task['haml_lint'].invoke
    rescue RuntimeError # The haml_lint tasks raise a RuntimeError
      exit(1)
    end

    desc "glimmer | Lint | Run several lint checks"
    task :all do
      status = 0

      tasks = %w[
        config_lint
        lint:haml
        gettext:lint
        lint:static_verification
        glimmer:sidekiq:all_queues_yml:check
      ]

      tasks.each do |task|
        pid = Process.fork do
          puts "*** Running rake task: #{task} ***"

          Rake::Task[task].invoke
        rescue SystemExit => ex
          warn "!!! Rake task #{task} exited:"
          raise ex
        rescue StandardError, ScriptError => ex
          warn "!!! Rake task #{task} raised #{ex.class}:"
          raise ex
        end

        Process.waitpid(pid)
        status += $?.exitstatus
      end

      exit(status)
    end
  end
end
