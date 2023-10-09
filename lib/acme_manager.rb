require 'logger'
require 'acme-client'
require 'fileutils'
require 'acme_manager/certificate'
require 'acme_manager/server'

module AcmeManager

  def self.client
    @client ||= begin
      private_key = OpenSSL::PKey::RSA.new(File.read(File.join(data_path, 'private.key')))
      client = Acme::Client.new(private_key: private_key, directory: self.directory, connection_options: { request: { open_timeout: 5, timeout: 5 } })
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
      AcmeManager.log_status(status, {:domain => certificate.name})
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
    client.new_account(contact: 'mailto:' + self.email_address, terms_of_service_agreed: true)
  rescue Acme::Client::Error::Malformed => e
    raise unless e.message =~ /Registration key is already in use/
  end

  def self.data_path
    File.expand_path(File.join(File.dirname(__FILE__), '..', 'data'))
  end

  def self.directory=(directory)
    @directory = directory
  end

  def self.directory
    @directory || raise("Directory URL not set")
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

  def self.pre_renewal_check=(proc)
    @pre_renewal_check = proc
  end

  def self.pre_renewal_check
    @pre_renewal_check || proc { true }
  end

  def self.post_commands=(post_commands)
    @post_commands = post_commands
  end

  def self.post_commands
    @post_commands || []
  end

  def self.run_post_commands
    unless AcmeManager.post_commands.empty?
      pid = spawn(AcmeManager.post_commands.join(';'))
      Process.detach(pid)
    end
  end

  def self.can_run_renewals?
    return AcmeManager.pre_renewal_check.call
  end

  def self.logger
    @logger ||= Logger.new(File.join(File.dirname(__FILE__), '..', 'manager.log'))
  end

  def self.log_status(status, *args)
    method = status[:result] == :failed ? :error : :info
    AcmeManager.logger.send(method, {:args => [*args]}.merge(status).to_json)
  end

end

config_file = File.join(File.dirname(__FILE__), '..', 'config.rb')
if File.exist?(config_file)
  require config_file
else
  raise("Config file not found")
end
