module AcmeManager
  class Certificate
    attr_accessor :name, :certificate

    def initialize(name, pem_data)
      @name = name
      @certificate = OpenSSL::X509::Certificate.new(pem_data)
    end

    def due_for_renewal?
      @certificate.not_after < Time.now + (30 * 24 * 3600)
    end

    def expired?
      true
      @certificate.not_after < Time.now
    end

    def to_json(options={})
      {:name => @name, :not_after => @certificate.not_after.iso8601}.to_json
    end

    def purge
      Certificate.purge(@name)
    end

    def renew
      status = Certificate.issue(@name)
      if status == :failed && expired?
        return purge 
      end
      status
    end

    def self.purge(domain)
      FileUtils.rm_rf(File.join(AcmeManager.data_path, 'certificates', domain))
      FileUtils.rm_rf(File.join(AcmeManager.data_path, 'assembled_certificates', domain + '.pem'))

      {:result => :purged}
    rescue StandardError => e
      {:result => :failed, :reason => {:type => e.class.name, :detail => e.message}}
    end

    def self.issue(domain)
      tries ||= 3
      if AcmeManager[domain] and !AcmeManager[domain].due_for_renewal?
        return { :result => :not_due }
      end

      order = AcmeManager.client.new_order(:identifiers => [domain])
      authorization = order.authorizations.first
      challenge = authorization.http
      File.write(File.join(AcmeManager.data_path, 'challenges', challenge.token), challenge.file_content)
      challenge.request_validation

      checks = 0
      until challenge.status != 'pending'
        checks += 1
        if checks > 30
          return { :result => :failed, :reason => { :type => :timeout, :detail => "Timeout waiting for verify result" } }
        end

        sleep 2
        challenge.reload
      end

      unless challenge.status == 'valid'
        return { :result => :failed, :reason => challenge.error }
      end

      private_key = OpenSSL::PKey::RSA.new(2048)
      csr = OpenSSL::X509::Request.new
      csr.subject = OpenSSL::X509::Name.new([['CN', domain, OpenSSL::ASN1::UTF8STRING]])
      csr.public_key = private_key.public_key
      csr.sign(private_key, OpenSSL::Digest::SHA256.new)
      order.finalize(:csr => csr)

      FileUtils.mkdir_p(File.join(AcmeManager.data_path, 'certificates', domain))
      File.write(File.join(AcmeManager.data_path, 'certificates', domain, 'key.pem'), private_key.to_pem)
      File.write(File.join(AcmeManager.data_path, 'certificates', domain, 'cert.pem'), order.certificate)

      assembled = order.certificate + private_key.to_pem
      File.write(File.join(AcmeManager.data_path, 'assembled_certificates', domain + '.pem'), assembled)
      { :result => :issued }
    rescue Acme::Client::Error => e
      tries -= 1
      if e.is_a?(Acme::Client::Error::BadNonce) && tries > 0
        retry
      else
        return {:result => :failed, :reason => {:type => :external, :detail => "#{e.class}: #{e.message}"}}
      end
    rescue => e
      return {:result => :failed, :reason => {:type => :internal, :detail => "#{e.class}: #{e.message}"}}
    end
  end
end
