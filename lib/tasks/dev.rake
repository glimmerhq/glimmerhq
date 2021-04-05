# frozen_string_literal: true

task dev: ["dev:setup"]

namespace :dev do
  desc "glimmer | Dev | Setup developer environment (db, fixtures)"
  task setup: :environment do
    ENV['force'] = 'yes'
    Rake::Task["glimmer:setup"].invoke

    # Make sure DB statistics are up to date.
    ActiveRecord::Base.connection.execute('ANALYZE')

    Rake::Task["glimmer:shell:setup"].invoke
  end

  desc "glimmer | Dev | Eager load application"
  task load: :environment do
    Rails.configuration.eager_load = true
    Rails.application.eager_load!
  end
end
