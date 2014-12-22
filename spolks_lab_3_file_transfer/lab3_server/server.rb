require 'socket'
require 'colorize'
require_relative '../message.rb'

server = Socket.new(Socket::PF_INET, Socket::SOCK_STREAM)

# Returns an addrinfo object for TCP address.
local_addrinfo = Addrinfo.tcp('10.42.0.1', 27015)

# Binds to the given local address.
begin
  server.bind(local_addrinfo)
rescue Errno::EADDRINUSE => addruse_error
  puts ('Error of the socket bind. ' + addruse_error.message).red
  server.close
  exit 1
end

# Listens for connections, using the specified int as the maximum length of the queue for pending connections.
server.listen 1

client = nil
client_addr_info = nil

puts 'Server waits for connections...'.green

client, client_addr_info = server.accept
puts "Accepted connection from #{client_addr_info.ip_address}".green

file_seek = Message.receive client, client_addr_info, 15, 15

f = File.open('files/page.html').binmode
f.seek(Integer(file_seek))

tf = TFile.new('page.html', f.read)

begin
  tf.send(client, client_addr_info)
rescue SendFileException => send_file_ex
  puts format(
              'Send File Exception. %s. File: %s. To: %s'.red,
              send_file_ex.message,
              send_file_ex.file_name,
              send_file_ex.destination_id
             )
end

client.close
server.close