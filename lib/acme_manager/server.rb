require 'json'

module AcmeManager
  class Server
    def call(env)
      if env['HTTP_X_API_KEY'] == AcmeManager.api_key
        case env['REQUEST_PATH']
        when '/~acmemanager/list'
          [200, {'Content-Type' => 'text/plain'}, [AcmeManager.certificates.to_json]]
        when /\A\/~acmemanager\/issue\/(.+)/
          domain = $1
          result = Certificate.issue(domain)
          if result == :issued
            pid = spawn(AcmeManager.post_commands.join(';'))
            Process.detach(pid)
          end
          response = {:result => result}
          [200, {'Content-Type' => 'text/plain'}, [response.to_json]]
        when /\A\/.well-known\/acme-challenge\/(.+)/
          token = $1
          [200, {'Content-Type' => 'text/plain'}, [File.read(File.join(AcmeManager.data_path, 'challenges', token))]]
        else
          [404, {}, ["Not found"]]
        end
      else
        [403, {}, ["API key required"]]
      end
    end
  end
end
