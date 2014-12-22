require 'socket'
require 'colored'
require_relative '../message.rb'

def send_file(s)
  file = File.open('files/page.html', 'r')
  file.binmode

  conf_number = 0
  begin
    data = file.read(Package::MAX_DATA_SIZE)
    package = Package.new(data, conf_number)

    conf_failed_count = 0
    begin
      package.send(s, true)
    rescue ConfirmFailedException => confirm_failed_exception
      conf_failed_count += 1
      retry unless conf_failed_count > 20
      raise confirm_failed_exception
    else
      puts 'Sent and confirm package ' + conf_number.to_s.green
      sleep 0.5
    end

    conf_number += 1
  end until file.eof?
  file.close
end

server = UDPSocket.new
server_host, server_port = '10.42.0.1', 27015
server.bind(server_host, server_port)

puts format(
  'Server start on %s:%s',
  server_host.blue,
  server_port.to_s.blue
)

server.connect('10.42.0.72', 27015)
begin
  send_file(server)
rescue ReconnectFailedException => reconnect_failed_exception
  puts format(
    '%s. %s. %s',
    'Connection refused. Reconnect failed'.red,
    reconnect_failed_exception.message,
    'Server will be closed'.red
  )
rescue ConfirmFailedException => confirm_failed_exception
  puts format(
    '%s. %s. %s',
    'Client did not confirm package'.red,
    confirm_failed_exception.message,
    'Server will be closed'.red
  )
end

server.close