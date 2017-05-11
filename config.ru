$:.unshift File.join(File.dirname(__FILE__), 'lib')
require './lib/acme_manager'
run AcmeManager::Server.new
