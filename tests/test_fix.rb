require 'minitest/autorun'
require 'json'
require 'ostruct'

# Mock dependencies by intercepting require
module Kernel
  alias_method :original_require, :require
  def require(name)
    if ['net/ssh', 'rest-client', 'tty-progressbar'].include?(name)
      return true
    end
    original_require(name)
  end
end

# Define Mock Modules that are included/used
module RestClient
  class Request
    def self.execute(args); end
  end
end

module TTY
  class ProgressBar
    def initialize(*args); end
    def advance; end
  end
end

# Load the library
require_relative '../classes/PineappleMK7.rb'

class TestScanning < Minitest::Test
  def setup
    # Mock Authentication constants
    unless defined?(PineappleMK7::System::Authentication::API_URL)
        PineappleMK7::System::Authentication.const_set(:API_URL, 'http://mock:1471/api/')
        PineappleMK7::System::Authentication.const_set(:BEARER_TOKEN, 'mock_token')
    end

    @scanning = PineappleMK7::Modules::Recon::Scanning.new
  end

  def test_start_band_parameter
    mock_response = OpenStruct.new(body: '{"scanRunning":true,"scanID":1}')

    # Stub sleep to avoid waiting
    @scanning.stub :sleep, nil do
        RestClient::Request.stub :execute, ->(args) {
            payload = JSON.parse(args[:payload])
            if payload['band'] == '5'
                @band_correct = true
            else
                @band_correct = false
            end
            mock_response
        } do
            # Use scan_time 0 so logic defaults to 30, but we stubbed sleep
            @scanning.start(0, '5')
        end
    end

    assert @band_correct, "Band parameter should be '5'"
  end

  def test_oui_caching
    mock_response_oui = OpenStruct.new(body: '{"available":true, "vendor":"TestVendor"}')
    # Use a real JSON structure for scan results
    mock_response_scan = OpenStruct.new(
        body: '{"APResults":[{"bssid":"00:11:22:33:44:55", "encryption":0, "clients":[]}], "UnassociatedClientResults":[], "OutOfRangeClientResults":[]}'
    )

    call_count = 0

    execute_stub = ->(args) {
        if args[:url].include?('helpers/lookupOUI')
            call_count += 1
            mock_response_oui
        elsif args[:url].include?('recon/scans')
            mock_response_scan
        else
            OpenStruct.new(body: '{}')
        end
    }

    RestClient::Request.stub :execute, execute_stub do
        # First call
        @scanning.output(1)
        # Second call
        @scanning.output(1)
    end

    assert_equal 1, call_count, "OUI lookup should be cached and called only once"
  end

  def test_requester_json_error
    requester = PineappleMK7::Modules::Recon::Scanning.new

    bad_json_body = '{"success":true, broken...}'
    mock_response = OpenStruct.new(body: bad_json_body)

    RestClient::Request.stub :execute, ->(args) { mock_response } do
        # stop_continuous expects {"success":true} in response
        result = requester.stop_continuous
        # Should return the body as string instead of crashing
        assert_equal bad_json_body, result
    end
  end
end
