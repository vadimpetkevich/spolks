require 'socket'
require 'colorize'
require_relative '../message.rb'

client = Socket.new(Socket::PF_INET, Socket::SOCK_STREAM)

puts 'Enter the port number:'.blue
begin
  port= Integer (gets).chop
rescue ArgumentError
  puts 'Invalid port value. Enter again'.red
  retry
end

puts 'Enter the host name:'.blue
host = (gets).chop

# Returns an addrinfo object for TCP address.
begin
  addr_for_connect = Addrinfo.tcp(host, port)
rescue SocketError
  puts 'Failed to obtain addr_info for server. Client will be closed'.red
  client.close
  exit 1
end

client.connect addr_for_connect
puts format('Connected to %s'.green, addr_for_connect.ip_address)

file_size = File.exist?('files/page.html') ? File.size('files/page.html') : 0
Message.new(file_size.to_s).send client, addr_for_connect

begin
  TFile.receive_and_save('page.html', client, addr_for_connect, 15, 15)
rescue TimeoutException => timeout_expired
  puts format(
               'Server timeout is expired. Server ip: %s'.red,
               timeout_expired.host_ip
             )
rescue HandlerDisconnectException => server_disconnect_exception
  puts format(
               'Server disconnect. %s. Server ip: %s'.red,
               server_disconnect_exception.message,
               server_disconnect_exception.host_ip
             )
rescue BrokenFileException => broken_file_exception
  puts format(
               'Server sent broken message. %s. Server ip: %s'.red,
               broken_file_exception.message,
               broken_file_exception.sender_id
             )
end

client.close