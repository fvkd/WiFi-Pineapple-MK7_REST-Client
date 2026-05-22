require 'minitest/autorun'
require 'minitest/mock'

# Mock namespaces to avoid requiring missing dependencies
module Net
  module SSH
    def self.start(host, user, options, &block)
      # To be stubbed
    end
  end
end

module PineappleMK7
  module System
    module Authentication
      PINEAPPLE_HOST = '127.0.0.1'
      PINEAPPLE_PASSWORD = 'password'
    end
  end
end

# Require the module under test
require_relative '../includes/System/LED.rb'

# Create a class to include the module
module PineappleMK7
  module System
    class LED
      include M_LED
    end
  end
end

class TestLED < Minitest::Test
  def setup
    @led = PineappleMK7::System::LED.new
  end

  def test_setup
    verify_led_command('SETUP', :setup)
  end

  def test_failed
    verify_led_command('FAIL', :failed)
  end

  def test_attack
    verify_led_command('ATTACK', :attack)
  end

  def test_special
    verify_led_command('SPECIAL', :special)
  end

  def test_cleanup
    verify_led_command('CLEANUP', :cleanup)
  end

  def test_finish
    verify_led_command('FINISH', :finish)
  end

  def test_off
    verify_led_command('OFF', :off)
  end

  def test_execute_error
    error_message = "SSH Connection Error"

    # Stub Net::SSH.start to raise an error
    Net::SSH.stub :start, ->(*_args) { raise StandardError.new(error_message) } do
      # Mock abort to prevent process exit and verify message
      @led.stub :abort, ->(msg) { throw :abort_called, msg } do
        msg = catch(:abort_called) do
          @led.setup
          nil
        end
        assert_equal "System::LED => #{error_message}", msg
      end
    end
  end

  private

  def verify_led_command(state, method_name)
    ssh_client_mock = Minitest::Mock.new
    ssh_client_mock.expect :exec, nil, ["/sbin/LED #{state}"]

    Net::SSH.stub :start, ->(host, user, options, &block) {
      assert_equal PineappleMK7::System::Authentication::PINEAPPLE_HOST, host
      assert_equal 'root', user
      assert_equal PineappleMK7::System::Authentication::PINEAPPLE_PASSWORD, options[:password]
      block.call(ssh_client_mock)
    } do
      @led.send(method_name)
    end

    ssh_client_mock.verify
  end
end
