require 'socket'
require 'colored'
require_relative '../message.rb'

def get_file s
  file = File.open('files/page.html', 'w')
  file.binmode

  current_conf_number = 0
  loop do
    timeout_count = 0
    broken_package_count = 0

    begin
      data, conf_number = Package.receive(s, 1, true)
    rescue TimeoutException => timeout_exception
      timeout_count += 1
      retry unless timeout_count > 20
      raise timeout_exception
    rescue BrokenPackageException => broken_package_exception
      timeout_count = 0
      broken_package_count += 1
      retry unless broken_package_count > 5
      raise broken_package_exception
    else
      puts 'Recv package ' + conf_number.to_s.green
    end

    file.write(data) if current_conf_number == conf_number
    current_conf_number += 1
  end
  file.close
end

client = UDPSocket.new
client_host, client_port = '10.42.0.72', 27015
client.bind client_host, client_port

puts format(
  'Client start on %s:%s',
  client_host.blue,
  client_port.to_s.blue
)

client.connect('10.42.0.1', 27015)
begin
  get_file(client)
rescue ReconnectFailedException => reconnect_failed_exception
  puts format(
    '%s. %s. %s',
    'Connection refused. Reconnect failed'.red,
    reconnect_failed_exception.message,
    'Client will be closed'.red
  )
rescue BrokenPackageException => broken_package_exception
  puts format(
    '%s. %s. %s',
    'Server did send broken package 5 times'.red,
    broken_package_exception.message,
    'Client will be closed'.red
  )
rescue TimeoutException => timeout_exception
  puts format(
    '%s. %s. %s',
    'Server did not send package 20 times'.red,
    timeout_exception.message,
    'Client will be closed'.red
  )
end

client.close