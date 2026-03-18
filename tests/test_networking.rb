require 'minitest/autorun'
require 'minitest/mock'
require 'ostruct'
require_relative '../includes/Modules/Settings/Networking'

class TestNetworking < Minitest::Test
  class Dummy
    include M_Networking
    def call(method, uri, payload, confirm)
    end
  end

  def setup
    @networking = Dummy.new
  end

  def test_interfaces
    mock = Minitest::Mock.new
    mock.expect :call, nil, ['GET', 'settings/networking/interfaces', '', '[{']

    @networking.stub :call, proc { |*args| mock.call(*args) } do
      @networking.interfaces
    end

    assert mock.verify
  end

  def test_client_scan
    interface = 'wlan1'
    mock = Minitest::Mock.new
    mock.expect :call, nil, ['POST', 'settings/networking/clientmode/scan', { "interface" => interface }, '{"results":[']

    @networking.stub :call, proc { |*args| mock.call(*args) } do
      @networking.client_scan(interface)
    end

    assert mock.verify
  end

  def test_client_connect
    interface = 'wlan1'
    network = OpenStruct.new(
      ssid: 'TestSSID',
      bssid: '00:11:22:33:44:55',
      password: 'password123',
      encryption: 'WPA2',
      hidden: false
    )
    mock = Minitest::Mock.new
    mock.expect :call, nil, [
      'POST',
      'settings/networking/clientmode/connect',
      {
        "ssid" => network.ssid,
        "bssid" => network.bssid,
        "password" => network.password,
        "encryption" => network.encryption,
        "hidden" => network.hidden,
        "interface" => interface
      },
      '{"success":true}'
    ]

    @networking.stub :call, proc { |*args| mock.call(*args) } do
      @networking.client_connect(network, interface)
    end

    assert mock.verify
  end

  def test_client_disconnect
    interface = 'wlan1'
    mock = Minitest::Mock.new
    mock.expect :call, nil, ['POST', 'settings/networking/clientmode/disconnect', { "interface" => interface }, '{"success":true}']

    @networking.stub :call, proc { |*args| mock.call(*args) } do
      @networking.client_disconnect(interface)
    end

    assert mock.verify
  end

  def test_recon_interface
    interface = 'wlan2'
    mock = Minitest::Mock.new
    mock.expect :call, nil, ['PUT', 'settings/networking/recon/interface', { "interface" => interface }, '{"success":true}']

    @networking.stub :call, proc { |*args| mock.call(*args) } do
      @networking.recon_interface(interface)
    end

    assert mock.verify
  end
end
