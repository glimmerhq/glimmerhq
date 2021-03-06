# frozen_string_literal: true

require 'resolv'

class InstanceConfiguration
  SSH_ALGORITHMS = %w(DSA ECDSA ED25519 RSA).freeze
  SSH_ALGORITHMS_PATH = '/etc/ssh/'
  CACHE_KEY = 'instance_configuration'
  EXPIRATION_TIME = 24.hours

  def settings
    @configuration ||= Rails.cache.fetch(CACHE_KEY, expires_in: EXPIRATION_TIME) do
      { ssh_algorithms_hashes: ssh_algorithms_hashes,
        host: host,
        glimmer_pages: glimmer_pages,
        glimmer_ci: glimmer_ci }.deep_symbolize_keys
    end
  end

  private

  def ssh_algorithms_hashes
    SSH_ALGORITHMS.map { |algo| ssh_algorithm_hashes(algo) }.compact
  end

  def host
    Settings.glimmer.host
  end

  def glimmer_pages
    Settings.pages.to_h.merge(ip_address: resolv_dns(Settings.pages.host))
  end

  def resolv_dns(dns)
    Resolv.getaddress(dns)
  rescue Resolv::ResolvError
  end

  def glimmer_ci
    Settings.glimmer_ci
            .to_h
            .merge(artifacts_max_size: { value: Glimmer::CurrentSettings.max_artifacts_size.megabytes,
                                         default: 100.megabytes })
  end

  def ssh_algorithm_file(algorithm)
    File.join(SSH_ALGORITHMS_PATH, "ssh_host_#{algorithm.downcase}_key.pub")
  end

  def ssh_algorithm_hashes(algorithm)
    content = ssh_algorithm_file_content(algorithm)
    return unless content.present?

    { name: algorithm,
      md5: ssh_algorithm_md5(content),
      sha256: ssh_algorithm_sha256(content) }
  end

  def ssh_algorithm_file_content(algorithm)
    file = ssh_algorithm_file(algorithm)
    return unless File.exist?(file)

    File.read(file)
  end

  def ssh_algorithm_md5(ssh_file_content)
    Glimmer::SSHPublicKey.new(ssh_file_content).fingerprint
  end

  def ssh_algorithm_sha256(ssh_file_content)
    Glimmer::SSHPublicKey.new(ssh_file_content).fingerprint('SHA256')
  end
end
