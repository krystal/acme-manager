require 'json'

module AcmeManager
  class Server
    def call(env)
      case env['REQUEST_PATH']
      when '/'
        [200, {'Content-Type' => 'text/plain'}, [AcmeManager.certificates.to_json]]
      when /\/issue\/(.+)/
        domain = $1
        response = {:result => Certificate.issue(domain)}
        [200, {'Content-Type' => 'text/plain'}, [response.to_json]]
      when /\/.well-known\/acme-challenge\/(.+)/
        token = $1
        [200, {'Content-Type' => 'text/plain'}, [File.read(File.join('data', 'challenges', token))]]
      end
    end
  end
end
