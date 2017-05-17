require 'json'

module AcmeManager
  class Server
    def call(env)
      case env['REQUEST_PATH']
      when '/~acmemanager/list'
        if env['HTTP_X_API_KEY'] == AcmeManager.api_key
          [200, {'Content-Type' => 'text/plain'}, [AcmeManager.certificates.to_json]]
        else
          [403, {}, ["API key required"]]
        end
      when /\A\/~acmemanager\/issue\/(.+)/
        if env['HTTP_X_API_KEY'] == AcmeManager.api_key
          domain = $1
          result = Certificate.issue(domain)
          if result[:result] == :issued
            pid = spawn(AcmeManager.post_commands.join(';'))
            Process.detach(pid)
          end
          [200, {'Content-Type' => 'text/plain'}, [result.to_json]]
        else
          [403, {}, ["API key required"]]
        end
      when /\A\/.well-known\/acme-challenge\/(.+)/
        token = $1
        begin
          [200, {'Content-Type' => 'text/plain'}, [File.read(File.join(AcmeManager.data_path, 'challenges', token))]]
        rescue Errno::ENOENT
          [404, {}, ["Not found"]]
        end
      else
        [404, {}, ["Not found"]]
      end
    rescue => e
      [500, {}, [{:result => :failed, :reason => {:type => :internal, :detail => "#{e.class}: #{e.message}"}}.to_json]]
    end

  end
end
