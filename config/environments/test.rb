require 'glimmer/testing/request_blocker_middleware'
require 'glimmer/testing/robots_blocker_middleware'
require 'glimmer/testing/request_inspector_middleware'
require 'glimmer/testing/clear_process_memory_cache_middleware'
require 'glimmer/utils'

Rails.application.configure do
  # Make sure the middleware is inserted first in middleware chain
  config.middleware.insert_before(ActionDispatch::Static, Glimmer::Testing::RequestBlockerMiddleware)
  config.middleware.insert_before(ActionDispatch::Static, Glimmer::Testing::RobotsBlockerMiddleware)
  config.middleware.insert_before(ActionDispatch::Static, Glimmer::Testing::RequestInspectorMiddleware)
  config.middleware.insert_before(ActionDispatch::Static, Glimmer::Testing::ClearProcessMemoryCacheMiddleware)

  # Settings specified here will take precedence over those in config/application.rb

  # The test environment is used exclusively to run your application's
  # test suite. You never need to work with it otherwise. Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs. Don't rely on the data there!
  config.cache_classes = Glimmer::Utils.to_boolean(ENV['CACHE_CLASSES'], default: false)

  # Configure static asset server for tests with Cache-Control for performance
  config.assets.compile = false if ENV['CI']

  config.public_file_server.enabled = true
  config.public_file_server.headers = { 'Cache-Control' => 'public, max-age=3600' }

  # Show full error reports and disable caching
  config.active_record.verbose_query_logs  = true
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Raise exceptions instead of rendering exception templates
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment
  config.action_controller.allow_forgery_protection = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Print deprecation notices to the stderr
  config.active_support.deprecation = :stderr

  config.eager_load = Glimmer::Utils.to_boolean(ENV['GLIMMER_TEST_EAGER_LOAD'], default: true)

  config.cache_store = :null_store

  config.active_job.queue_adapter = :test

  if ENV['CI'] && !ENV['RAILS_ENABLE_TEST_LOG']
    config.logger = ActiveSupport::TaggedLogging.new(Logger.new(nil))
    config.log_level = :fatal
  end

  # Mount the ActionCable Engine in-app so that we don't have to spawn another Puma
  # process for feature specs
  ENV['ACTION_CABLE_IN_APP'] = 'true'
end
