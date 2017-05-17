require 'acme-client'
require 'fileutils'
require 'acme_manager/certificate'
require 'acme_manager/server'

module AcmeManager

  def self.client
    @client ||= begin
      private_key = OpenSSL::PKey::RSA.new(File.read(File.join(data_path, 'private.key')))
      client = Acme::Client.new(private_key: private_key, endpoint: self.endpoint, connection_options: { request: { open_timeout: 5, timeout: 5 } })
    end
  end

  def self.certificates
    domains = Dir.entries(File.join(data_path, 'certificates')).reject { |domain| domain =~ /\A\./ }
    domains.map do |domain|
      pem_data = File.read(File.join(data_path, 'certificates', domain, 'cert.pem'))
      Certificate.new(domain, pem_data)
    end
  end

  def self.certificates_due_for_renewal
    self.certificates.select { |certificate| certificate.due_for_renewal? }
  end

  def self.renew_all
    new_issues = false
    self.certificates_due_for_renewal.each do |certificate|
      status = certificate.renew
      new_issues = true if status[:result] == :issued
    end
    new_issues
  end

  def self.[](domain)
    if File.exist?(File.join(data_path, 'certificates', domain, 'cert.pem'))
      pem_data = File.read(File.join(data_path, 'certificates', domain, 'cert.pem'))
      Certificate.new(domain, pem_data)
    else
      nil
    end
  end

  def self.make_directories
    FileUtils.mkdir_p(File.join(data_path, 'challenges'))
    FileUtils.mkdir_p(File.join(data_path, 'certificates'))
    FileUtils.mkdir_p(File.join(data_path, 'assembled_certificates'))
  end

  def self.generate_private_key
    path = File.join(data_path, 'private.key')
    unless File.exist?(path)
      private_key = OpenSSL::PKey::RSA.new(4096).to_pem
      File.write(path, private_key)
    end
  end

  def self.accept_tos
    registration = client.register(contact: 'mailto:' + self.email_address)
    registration.agree_terms
  rescue Acme::Client::Error::Malformed => e
    raise unless e.message =~ /Registration key is already in use/
  end

  def self.data_path
    File.expand_path(File.join(File.dirname(__FILE__), '..', 'data'))
  end

  def self.endpoint=(endpoint)
    @endpoint = endpoint
  end

  def self.endpoint
    @endpoint || raise("Endpoint URL not set")
  end

  def self.email_address=(email_address)
    @email_address = email_address
  end

  def self.email_address
    @email_address || raise("Email Address not set")
  end

  def self.api_key=(api_key)
    @api_key = api_key
  end

  def self.api_key
    @api_key || raise("API Key not set")
  end

  def self.post_commands=(post_commands)
    @post_commands = post_commands
  end

  def self.post_commands
    @post_commands || []
  end

end

config_file = File.join(File.dirname(__FILE__), '..', 'config.rb')
if File.exist?(config_file)
  require config_file
else
  raise("Config file not found")
end
