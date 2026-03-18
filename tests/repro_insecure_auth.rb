require 'minitest/autorun'
require 'json'
require 'ostruct'

# Mock dependencies
module RestClient
  class Request
    def self.execute(args); end
  end
end

# The module uses Request.execute directly, which is RestClient::Request.execute since RestClient is included in the class.
# In Authentication.rb, it's just Request.execute.
# Let's define Request in the top level as well to be sure.
class Request < RestClient::Request; end

# Load the module
require_relative '../includes/System/Authentication'

class TestAuthentication < Minitest::Test
  class Dummy
    include M_Authentication
    attr_accessor :host, :port, :password
  end

  def setup
    @auth = Dummy.new
    @auth.host = '127.0.0.1'
    @auth.port = 1471
    @auth.password = 'password'
  end

  def test_login_uses_https
    captured_url = nil
    mock_response = OpenStruct.new(body: '{"token":"mock_token"}')

    # We need to stub Request.execute if that's what's called
    Request.stub :execute, ->(args) {
      captured_url = args[:url]
      mock_response
    } do
      @auth.login
    end

    assert_match %r{^https://}, captured_url, "URL should start with https://"
  end
end
