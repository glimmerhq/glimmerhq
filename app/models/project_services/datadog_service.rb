# frozen_string_literal: true

class DatadogService < Service
  DEFAULT_SITE = 'datadoghq.com'
  URL_TEMPLATE = 'https://webhooks-http-intake.logs.%{datadog_site}/v1/input/'
  URL_TEMPLATE_API_KEYS = 'https://app.%{datadog_site}/account/settings#api'
  URL_API_KEYS_DOCS = "https://docs.#{DEFAULT_SITE}/account_management/api-app-keys/"

  SUPPORTED_EVENTS = %w[
    pipeline job
  ].freeze

  prop_accessor :datadog_site, :api_url, :api_key, :datadog_service, :datadog_env

  with_options if: :activated? do
    validates :api_key, presence: true, format: { with: /\A\w+\z/ }
    validates :datadog_site, format: { with: /\A[\w\.]+\z/, allow_blank: true }
    validates :api_url, public_url: { allow_blank: true }
    validates :datadog_site, presence: true, unless: -> (obj) { obj.api_url.present? }
    validates :api_url, presence: true, unless: -> (obj) { obj.datadog_site.present? }
  end

  after_save :compose_service_hook, if: :activated?

  def initialize_properties
    super

    self.datadog_site ||= DEFAULT_SITE
  end

  def self.supported_events
    SUPPORTED_EVENTS
  end

  def self.default_test_event
    'pipeline'
  end

  def configurable_events
    [] # do not allow to opt out of required hooks
  end

  def title
    'Datadog'
  end

  def description
    'Trace your GitLab pipelines with Datadog'
  end

  def help
    nil
    # Maybe adding something in the future
    # We could link to static help pages as well
    # [More information](#{Gitlab::Routing.url_helpers.help_page_url('integration/datadog')})"
  end

  def self.to_param
    'datadog'
  end

  def fields
    [
      {
        type: 'text',
        name: 'datadog_site',
        placeholder: DEFAULT_SITE,
        help: 'Choose the Datadog site to send data to. Set to "datadoghq.eu" to send data to the EU site',
        required: false
      },
      {
        type: 'text',
        name: 'api_url',
        title: 'API URL',
        help: '(Advanced) Define the full URL for your Datadog site directly',
        required: false
      },
      {
        type: 'password',
        name: 'api_key',
        title: _('API key'),
        non_empty_password_title: s_('ProjectService|Enter new API key'),
        non_empty_password_help: s_('ProjectService|Leave blank to use your current API key'),
        help: "<a href=\"#{api_keys_url}\" target=\"_blank\">API key</a> used for authentication with Datadog",
        required: true
      },
      {
        type: 'text',
        name: 'datadog_service',
        title: 'Service',
        placeholder: 'gitlab-ci',
        help: 'Name of this GitLab instance that all data will be tagged with'
      },
      {
        type: 'text',
        name: 'datadog_env',
        title: 'Env',
        help: 'The environment tag that traces will be tagged with'
      }
    ]
  end

  def compose_service_hook
    hook = service_hook || build_service_hook
    hook.url = hook_url
    hook.save
  end

  def hook_url
    url = api_url.presence || sprintf(URL_TEMPLATE, datadog_site: datadog_site)
    url = URI.parse(url)
    url.path = File.join(url.path || '/', api_key)
    query = { service: datadog_service.presence, env: datadog_env.presence }.compact
    url.query = query.to_query unless query.empty?
    url.to_s
  end

  def api_keys_url
    return URL_API_KEYS_DOCS unless datadog_site.presence

    sprintf(URL_TEMPLATE_API_KEYS, datadog_site: datadog_site)
  end

  def execute(data)
    return if project.disabled_services.include?(to_param)

    object_kind = data[:object_kind]
    object_kind = 'job' if object_kind == 'build'
    return unless supported_events.include?(object_kind)

    service_hook.execute(data, "#{object_kind} hook")
  end

  def test(data)
    begin
      result = execute(data)
      return { success: false, result: result[:message] } if result[:http_status] != 200
    rescue StandardError => error
      return { success: false, result: error }
    end

    { success: true, result: result[:message] }
  end
end
