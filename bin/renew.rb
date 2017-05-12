$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')
require 'acme_manager'
if AcmeManager.renew_all
  pid = spawn(AcmeManager.post_commands.join(';'))
  Process.detach(pid)
end
