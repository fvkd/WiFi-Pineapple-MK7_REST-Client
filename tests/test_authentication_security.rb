# Mocking dependencies
module RestClient
  module Request
  end
end
module TTY
end
def include(mod)
end

# Mocking net/ssh
module Net
  module SSH
  end
end

# Stubbing require to ignore missing gems
module Kernel
  alias_method :original_require, :require
  def require(name)
    if ['net/ssh', 'rest-client', 'tty-progressbar', 'base64', 'fileutils'].include?(name)
      return true
    end
    original_require(name)
  end
end

require 'minitest/autorun'
require 'json'
require 'ostruct'

# Now we can safely require the files
require_relative '../includes/System/Authentication.rb'
require_relative '../classes/PineappleMK7.rb'

class TestSecurityFix < Minitest::Test
  def test_constants_not_defined
    auth_class = PineappleMK7::System::Authentication

    # Ensure they are not defined as constants
    refute auth_class.const_defined?(:API_URL), "API_URL constant should not be defined"
    refute auth_class.const_defined?(:BEARER_TOKEN), "BEARER_TOKEN constant should not be defined"
    refute auth_class.const_defined?(:PINEAPPLE_HOST), "PINEAPPLE_HOST constant should not be defined"
    refute auth_class.const_defined?(:PINEAPPLE_MAC), "PINEAPPLE_MAC constant should not be defined"
    refute auth_class.const_defined?(:PINEAPPLE_PASSWORD), "PINEAPPLE_PASSWORD constant should not be defined"

    # Simulate setting values via the new private writers (as M_Authentication does)
    auth_class.send(:api_url=, "http://1.2.3.4:1471/api/")
    auth_class.send(:bearer_token=, "token123")
    auth_class.send(:pineapple_host=, "1.2.3.4")
    auth_class.send(:pineapple_mac=, "AA:BB:CC:DD:EE:FF")
    auth_class.send(:pineapple_password=, "secret")

    # After setting, constants should STILL not be defined
    refute auth_class.const_defined?(:API_URL), "API_URL constant should not be defined after setting"
    refute auth_class.const_defined?(:BEARER_TOKEN), "BEARER_TOKEN constant should not be defined after setting"

    # But values should be accessible via reader methods
    assert_equal "http://1.2.3.4:1471/api/", auth_class.api_url
    assert_equal "token123", auth_class.bearer_token
    assert_equal "1.2.3.4", auth_class.pineapple_host
    assert_equal "AA:BB:CC:DD:EE:FF", auth_class.pineapple_mac
    assert_equal "secret", auth_class.pineapple_password
  end

  def test_writers_are_private
    auth_class = PineappleMK7::System::Authentication
    assert_raises(NoMethodError) do
      auth_class.api_url = "something"
    end
  end
end
