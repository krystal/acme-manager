require 'acme-client'

module AcmeManager

  def self.client
    @client ||= begin
      private_key = OpenSSL::PKey::RSA.new(File.read('data/config/private.key'))
      endpoint = 'https://acme-staging.api.letsencrypt.org/'
      client = Acme::Client.new(private_key: private_key, endpoint: endpoint, connection_options: { request: { open_timeout: 5, timeout: 5 } })
    end
  end

end
