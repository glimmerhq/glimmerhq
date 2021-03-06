# frozen_string_literal: true

module Gitlab
  module ErrorTracking
    module Processor
      class ContextPayloadProcessor < ::Raven::Processor
        # This processor is added to inject application context into Sentry
        # events generated by Sentry built-in integrations. When the
        # integrations are re-implemented and use Gitlab::ErrorTracking, this
        # processor should be removed.
        def process(payload)
          return payload if ::Feature.enabled?(:sentry_processors_before_send, default_enabled: :yaml)

          context_payload = Gitlab::ErrorTracking::ContextPayloadGenerator.generate(nil, {})
          payload.deep_merge!(context_payload)
        end

        def self.call(event)
          return event unless ::Feature.enabled?(:sentry_processors_before_send, default_enabled: :yaml)

          Gitlab::ErrorTracking::ContextPayloadGenerator.generate(nil, {}).each do |key, value|
            event.public_send(key).deep_merge!(value) # rubocop:disable GitlabSecurity/PublicSend
          end

          event
        end
      end
    end
  end
end
