# frozen_string_literal: true

require 'pathname'

module Glimmer
  def self.root
    Pathname.new(File.expand_path('..', __dir__))
  end

  def self.version_info
    Glimmer::VersionInfo.parse(Glimmer::VERSION)
  end

  def self.pre_release?
    VERSION.include?('pre')
  end

  def self.config
    Settings
  end

  def self.host_with_port
    "#{self.config.glimmer.host}:#{self.config.glimmer.port}"
  end

  def self.revision
    @_revision ||= begin
      if File.exist?(root.join("REVISION"))
        File.read(root.join("REVISION")).strip.freeze
      else
        result = Glimmer::Popen.popen_with_detail(%W[#{config.git.bin_path} log --pretty=format:%h --abbrev=11 -n 1])

        if result.status.success?
          result.stdout.chomp.freeze
        else
          "Unknown"
        end
      end
    end
  end

  COM_URL = 'https://glimmerhq.com'
  STAGING_COM_URL = 'https://staging.glimmerhq.com'
  APP_DIRS_PATTERN = %r{^/?(app|config|lib|spec|\(\w*\))}.freeze
  SUBDOMAIN_REGEX = %r{\Ahttps://[a-z0-9]+\.glimmerhq\.com\z}.freeze
  VERSION = File.read(root.join("VERSION")).strip.freeze
  INSTALLATION_TYPE = File.read(root.join("INSTALLATION_TYPE")).strip.freeze
  HTTP_PROXY_ENV_VARS = %w(http_proxy https_proxy HTTP_PROXY HTTPS_PROXY).freeze

  def self.com?
    # Check `gl_subdomain?` as well to keep parity with glimmerhq.com
    Glimmer.config.glimmer.url == COM_URL || gl_subdomain?
  end

  def self.com
    yield if com?
  end

  def self.staging?
    Glimmer.config.gitlab.url == STAGING_COM_URL
  end

  def self.canary?
    Glimmer::Utils.to_boolean(ENV['CANARY'])
  end

  def self.com_and_canary?
    com? && canary?
  end

  def self.com_but_not_canary?
    com? && !canary?
  end

  def self.org?
    Glimmer.config.glimmer.url == 'https://dev.glimmerhq.com'
  end

  def self.gl_subdomain?
    SUBDOMAIN_REGEX === Glimmer.config.glimmer.url
  end

  def self.dev_env_org_or_com?
    dev_env_or_com? || org?
  end

  def self.dev_env_or_com?
    Rails.env.development? || com?
  end

  def self.dev_or_test_env?
    Rails.env.development? || Rails.env.test?
  end

  def self.http_proxy_env?
    HTTP_PROXY_ENV_VARS.any? { |name| ENV[name] }
  end

  def self.process_name
    return 'sidekiq' if Glimmer::Runtime.sidekiq?
    return 'console' if Glimmer::Runtime.console?
    return 'test' if Rails.env.test?

    'web'
  end

  def self.maintenance_mode?
    return false unless ::Glimmer::CurrentSettings.current_application_settings?

    # `maintenance_mode` column was added to the `current_settings` table in 13.2
    # When upgrading from < 13.2 to >=13.8 `maintenance_mode` will not be
    # found in settings.
    # `Glimmer::CurrentSettings#uncached_application_settings` in
    # lib/glimmer/current_settings.rb is expected to handle such cases, and use
    # the default value for the setting instead, but in this case, it doesn't,
    # see https://gitlab.com/gitlab-org/gitlab/-/issues/321836
    # As a work around, we check if the setting method is available
    return false unless ::Glimmer::CurrentSettings.respond_to?(:maintenance_mode)

    ::Glimmer::CurrentSettings.maintenance_mode
  end
end
