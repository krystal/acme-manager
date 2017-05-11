$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')
require 'acme_manager'
AcmeManager.renew_all
