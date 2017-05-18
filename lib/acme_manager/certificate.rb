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

    def delete!
      FileUtils.rm_rf(File.join(AcmeManager.data_path, 'certificates', domain))
      FileUtils.rm_rf(File.join(AcmeManager.data_path, 'assembled_certificates', domain + '.pem'))
    end

    def renew
      status = Certificate.issue(@name)
      if status == :failed && expired?
        delete!
        return {:result => :deleted}
      end
      status
    end

    def self.issue(domain)
      tries ||= 3
      if AcmeManager[domain] and !AcmeManager[domain].due_for_renewal?
        return {:result => :not_due}
      end
      authorization = AcmeManager.client.authorize(:domain => domain)
      if authorization.status == 'pending'
        challenge = authorization.http01
        File.write(File.join(AcmeManager.data_path, 'challenges', challenge.token), challenge.file_content)
        challenge.request_verification

        checks = 0
        sleep 1
        while challenge.verify_status == 'pending'
          checks += 1
          if checks > 5
            return {:result => :failed, :reason => {:type => :timeout, :detail => "Timeout waiting for verify result"}}
          end
          sleep 1
        end
        case challenge.verify_status
        when 'valid'
          # Carry on
        when 'invalid'
          return {:result => :failed, :reason => challenge.authorization.http01.error}
        else
          return {:result => :failed, :reason => {:type => :unexpected_status, :detail => challenge.verify_status}}
        end
      end

      csr = Acme::Client::CertificateRequest.new(:names => [domain])
      certificate = AcmeManager.client.new_certificate(csr)
      FileUtils.mkdir_p(File.join(AcmeManager.data_path, 'certificates', domain))
      File.write(File.join(AcmeManager.data_path, 'certificates', domain, 'key.pem'), certificate.request.private_key.to_pem)
      File.write(File.join(AcmeManager.data_path, 'certificates', domain, 'cert.pem'), certificate.to_pem)
      File.write(File.join(AcmeManager.data_path, 'certificates', domain, 'chain.pem'), certificate.chain_to_pem)

      assembled = certificate.to_pem + certificate.chain_to_pem + certificate.request.private_key.to_pem
      File.write(File.join(AcmeManager.data_path, 'assembled_certificates', domain + '.pem'), assembled)
      return {:result => :issued}
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
