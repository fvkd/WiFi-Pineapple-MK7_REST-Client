require 'minitest/autorun'
require 'minitest/mock'
require 'ostruct'
require_relative '../includes/Modules/PineAP/Clients'

class TestClients < Minitest::Test
  class Dummy
    include M_Clients
    def call(method, uri, payload, confirm)
    end
  end

  def setup
    @clients = Dummy.new
  end

  def test_connected_clients_empty
    @clients.stub :call, "null\r\n" do
      result = @clients.connected_clients
      assert_equal [], result
    end
  end

  def test_connected_clients_not_empty
    clients_data = [OpenStruct.new(mac: '00:11:22:33:44:55')]
    @clients.stub :call, clients_data do
      result = @clients.connected_clients
      assert_equal clients_data, result
    end
  end

  def test_previous_clients_empty
    @clients.stub :call, "null\r\n" do
      result = @clients.previous_clients
      assert_equal [], result
    end
  end

  def test_previous_clients_not_empty
    clients_data = [OpenStruct.new(mac: '66:77:88:99:AA:BB')]
    @clients.stub :call, clients_data do
      result = @clients.previous_clients
      assert_equal clients_data, result
    end
  end

  def test_kick
    mac = '00:11:22:33:44:55'
    mock = Minitest::Mock.new
    mock.expect :call, nil, ['DELETE', 'pineap/clients/kick', { "mac" => mac }, '{"success":true}']

    @clients.stub :call, proc { |*args| mock.call(*args) } do
      @clients.kick(mac)
    end

    assert mock.verify
  end

  def test_clear_previous
    clients_data = [OpenStruct.new(mac: 'AA:BB:CC:DD:EE:FF'), OpenStruct.new(mac: '11:22:33:44:55:66')]

    # We need to stub :previous_clients and also :call
    @clients.stub :previous_clients, clients_data do
      mock = Minitest::Mock.new
      clients_data.each do |client|
        mock.expect :call, nil, ['DELETE', 'pineap/previousclients/remove', { "mac" => client.mac }, '{"success":true}']
      end

      @clients.stub :call, proc { |*args| mock.call(*args) } do
        @clients.clear_previous
      end

      assert mock.verify
    end
  end
end
