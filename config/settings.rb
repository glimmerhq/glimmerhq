# frozen_string_literal: true

require 'settingslogic'
require 'digest/md5'

# We can not use `Rails.root` here, as this file might be loaded without the
# full Rails environment being loaded. We can not use `require_relative` either,
# as Rails uses `load` for `require_dependency` (used when loading the Rails
# environment). This could then lead to this file being loaded twice.
require_dependency File.expand_path('../lib/glimmer', __dir__)

class Settings < Settingslogic
  source ENV.fetch('GLIMMER_CONFIG') { Pathname.new(File.expand_path('..', __dir__)).join('config/glimmer.yml') }
  namespace ENV.fetch('GLIMMER_ENV') { Rails.env }

  class << self
    def glimmer_on_standard_port?
      on_standard_port?(glimmer)
    end

    def host_without_www(url)
      host(url).sub('www.', '')
    end

    def build_glimmer_ci_url
      custom_port =
        if on_standard_port?(glimmer)
          nil
        else
          ":#{glimmer.port}"
        end

      [
        glimmer.protocol,
        "://",
        glimmer.host,
        custom_port,
        glimmer.relative_url_root
      ].join('')
    end

    def build_pages_url
      base_url(pages).join('')
    end

    def build_glimmer_shell_ssh_path_prefix
      user = "#{glimmer_shell.ssh_user}@" unless glimmer_shell.ssh_user.empty?
      user_host = "#{user}#{glimmer_shell.ssh_host}"

      if glimmer_shell.ssh_port != 22
        "ssh://#{user_host}:#{glimmer_shell.ssh_port}/"
      else
        if glimmer_shell.ssh_host.include? ':'
          "[#{user_host}]:"
        else
          "#{user_host}:"
        end
      end
    end

    def build_base_glimmer_url
      base_url(glimmer).join('')
    end

    def build_glimmer_url
      (base_url(glimmer) + [glimmer.relative_url_root]).join('')
    end

    def build_glimmer_go_url
      # "Go package paths are not URLs, and do not include port numbers"
      # https://github.com/golang/go/issues/38213#issuecomment-607851460
      "#{glimmer.host}#{glimmer.relative_url_root}"
    end

    def kerberos_protocol
      kerberos.https ? "https" : "http"
    end

    def kerberos_port
      kerberos.use_dedicated_port ? kerberos.port : glimmer.port
    end

    # Curl expects username/password for authentication. However when using GSS-Negotiate not credentials should be needed.
    # By inserting in the Kerberos dedicated URL ":@", we give to curl an empty username and password and GSS auth goes ahead
    # Known bug reported in http://sourceforge.net/p/curl/bugs/440/ and http://curl.haxx.se/docs/knownbugs.html
    def build_glimmer_kerberos_url
      [
        kerberos_protocol,
        "://:@",
        glimmer.host,
        ":#{kerberos_port}",
        glimmer.relative_url_root
      ].join('')
    end

    def alternative_glimmer_kerberos_url?
      kerberos.enabled && (build_glimmer_kerberos_url != build_glimmer_url)
    end

    # check that values in `current` (string or integer) is a contant in `modul`.
    def verify_constant_array(modul, current, default)
      values = default || []
      unless current.nil?
        values = []
        current.each do |constant|
          values.push(verify_constant(modul, constant, nil))
        end
        values.delete_if { |value| value.nil? }
      end

      values
    end

    # check that `current` (string or integer) is a contant in `modul`.
    def verify_constant(modul, current, default)
      constant = modul.constants.find { |name| modul.const_get(name, false) == current }
      value = constant.nil? ? default : modul.const_get(constant, false)
      if current.is_a? String
        value = modul.const_get(current.upcase, false) rescue default
      end

      value
    end

    def absolute(path)
      File.expand_path(path, Rails.root)
    end

    # Ruby 2.4+ requires passing in the exact required length for OpenSSL keys
    # (https://github.com/ruby/ruby/commit/ce635262f53b760284d56bb1027baebaaec175d1).
    # Previous versions quietly truncated the input.
    #
    # Use this when using :per_attribute_iv mode for attr_encrypted.
    # We have to truncate the string to 32 bytes for a 256-bit cipher.
    def attr_encrypted_db_key_base_truncated
      Glimmer::Application.secrets.db_key_base[0..31]
    end

    def attr_encrypted_db_key_base_32
      Glimmer::Utils.ensure_utf8_size(attr_encrypted_db_key_base, bytes: 32.bytes)
    end

    def attr_encrypted_db_key_base_12
      Glimmer::Utils.ensure_utf8_size(attr_encrypted_db_key_base, bytes: 12.bytes)
    end

    # This should be used for :per_attribute_salt_and_iv mode. There is no
    # need to truncate the key because the encryptor will use the salt to
    # generate a hash of the password:
    # https://github.com/attr-encrypted/encryptor/blob/c3a62c4a9e74686dd95e0548f9dc2a361fdc95d1/lib/encryptor.rb#L77
    def attr_encrypted_db_key_base
      Glimmer::Application.secrets.db_key_base
    end

    def encrypted(path)
      Glimmer::EncryptedConfiguration.new(
        content_path: path,
        base_key: Glimmer::Application.secrets.encrypted_settings_key_base,
        previous_keys: Glimmer::Application.secrets.rotated_encrypted_settings_key_base || []
      )
    end

    def load_dynamic_cron_schedules!
      cron_jobs['glimmer_usage_ping_worker']['cron'] ||= cron_for_usage_ping
    end

    private

    def base_url(config)
      custom_port = on_standard_port?(config) ? nil : ":#{config.port}"

      [
        config.protocol,
        "://",
        config.host,
        custom_port
      ]
    end

    def on_standard_port?(config)
      config.port.to_i == (config.https ? 443 : 80)
    end

    # Extract the host part of the given +url+.
    def host(url)
      url = url.downcase
      url = "http://#{url}" unless url.start_with?('http')

      # Get rid of the path so that we don't even have to encode it
      url_without_path = url.sub(%r{(https?://[^/]+)/?.*}, '\1')

      URI.parse(url_without_path).host
    end

    # Runs at a consistent random time of day on a day of the week based on
    # the instance UUID. This is to balance the load on the service receiving
    # these pings. The sidekiq job handles temporary http failures.
    def cron_for_usage_ping
      # Set a default UUID for the case when the UUID hasn't been initialized.
      uuid = Glimmer::CurrentSettings.uuid || 'uuid-not-set'

      minute = Digest::MD5.hexdigest(uuid + 'minute').to_i(16) % 60
      hour = Digest::MD5.hexdigest(uuid + 'hour').to_i(16) % 24
      day_of_week = Digest::MD5.hexdigest(uuid).to_i(16) % 7

      "#{minute} #{hour} * * #{day_of_week}"
    end
  end
end
