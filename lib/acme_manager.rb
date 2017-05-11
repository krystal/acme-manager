require 'acme-client'
require 'fileutils'
require 'acme_manager/certificate'
require 'acme_manager/server'

module AcmeManager

  def self.client
    @client ||= begin
      private_key = OpenSSL::PKey::RSA.new(File.read('data/config/private.key'))
      endpoint = 'https://acme-staging.api.letsencrypt.org/'
      client = Acme::Client.new(private_key: private_key, endpoint: endpoint, connection_options: { request: { open_timeout: 5, timeout: 5 } })
    end
  end

  def self.certificates
    domains = Dir.entries(File.join('data', 'certificates')).reject { |domain| domain =~ /\A\./ }
    domains.map do |domain|
      pem_data = File.read(File.join('data', 'certificates', domain, 'cert.pem'))
      Certificate.new(domain, pem_data)
    end
  end

  def self.certificates_due_for_renewal
    self.certificates.select { |certificate| certificate.due_for_renewal? }
  end

  def self.renew_all
    self.certificates_due_for_renewal.each do |certificate|
      certificate.renew
    end
    true
  end

  def self.[](domain)
    if File.exist?(File.join('data', 'certificates', domain, 'cert.pem'))
      pem_data = File.read(File.join('data', 'certificates', domain, 'cert.pem'))
      Certificate.new(domain, pem_data)
    else
      nil
    end
  end

end
