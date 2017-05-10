module AcmeManager
  class Server
    def call(env)
      case env['REQUEST_PATH']
      when '/'
        [200, {"Content-Type" => "text/html"}, ["Hello!"]]
      when /\/issue\/(.+)/
        domain = $1
        authorization = AcmeManager.client.authorize(:domain => domain)
        if authorization.status == 'pending'
          challenge = authorization.http01
          File.write(File.join('data', 'challenges', challenge.token), challenge.file_content)
          challenge.request_verification
          sleep 1
        end
        csr = Acme::Client::CertificateRequest.new(:names => [domain])
        certificate = AcmeManager.client.new_certificate(csr)
        FileUtils.mkdir_p(File.join('data', 'certificates', 'domain'))
        File.write(File.join('data', 'certificates', 'domain', 'key.pem'), certificate.request.private_key.to_pem)
        File.write(File.join('data', 'certificates', 'domain', 'cert.pem'), certificate.to_pem)
        File.write(File.join('data', 'certificates', 'domain', 'chain.pem'), certificate.chain_to_pem)

        assembled = certificate.to_pem + certificate.chain_to_pem + certificate.request.private_key.to_pem
        File.write(File.join('data', 'assembled_certificates', domain + '.pem'), assembled)
        [200, {"Content-Type" => "text/html"}, ["Certificate issued!"]]
      when /\/.well-known\/acme-challenge\/(.+)/
        token = $1
        [200, {"Content-Type" => "text/html"}, [File.read(File.join('data', 'challenges', token))]]
      end
    end
  end
end
