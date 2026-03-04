require 'minitest/autorun'
require_relative '../includes/Modules/Recon/Scanning'

class TestScanning < Minitest::Test
  class Dummy
    include M_Scanning
  end

  def setup
    @scanning = Dummy.new
  end

  def test_convert_encryption_open
    assert_equal 'Open', @scanning.send(:convert_encryption, 0)
  end

  def test_convert_encryption_wep
    assert_equal 'WEP', @scanning.send(:convert_encryption, 1 << 1)
  end

  def test_convert_encryption_wpa
    assert_equal 'WPA', @scanning.send(:convert_encryption, 1 << 2)
  end

  def test_convert_encryption_wpa2
    assert_equal 'WPA2', @scanning.send(:convert_encryption, 1 << 3)
  end

  def test_convert_encryption_wpa3
    assert_equal 'WPA3', @scanning.send(:convert_encryption, 1 << 4)
  end

  def test_convert_encryption_unknown
    assert_equal 'Unknown', @scanning.send(:convert_encryption, 1 << 5)
  end

  def test_convert_encryption_nil
    assert_equal 'Unknown', @scanning.send(:convert_encryption, nil)
  end
end
