$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')
require 'acme_manager'
if AcmeManager.renew_all
  AcmeManager.run_post_commands
end
