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
            AcmeManager.run_post_commands
          end
          [200, {'Content-Type' => 'text/plain'}, [result.to_json]]
        else
          [403, {}, ["API key required"]]
        end
      when /\A\/~acmemanager\/purge\/(.+)/
        if env['HTTP_X_API_KEY'] == AcmeManager.api_key
          domain = $1
          result = Certificate.purge(domain)
          [200, {'Content-Type' => 'tex/plain'}, [result.to_json]]
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
      [500, {}, [{:result => :failed, :reason => {:type => :internal, :detail => "#{e.class}: #{e.message}, #{e.backtrace.join}"}}.to_json]]
    end

  end
end
