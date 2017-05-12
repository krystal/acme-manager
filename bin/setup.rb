$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')
require 'acme_manager'
AcmeManager.make_directories
AcmeManager.generate_private_key
AcmeManager.accept_tos
