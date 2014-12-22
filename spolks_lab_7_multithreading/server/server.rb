require 'socket'
require 'colored'
require_relative 'multithreading.rb'
require_relative '../message.rb'

server = UDPSocket.new
server_host, server_port = ARGV.first, Integer(ARGV.last)
server.bind(server_host, server_port)

puts format(
  'Server start on %s:%s',
  server_host.blue,
  server_port.to_s.blue
)

begin
  multithreading(server, server_host, server_port)
rescue Exception => ex
  puts format(
    '%s. %s. %s'.red,
    ex.class,
    ex.message,
    'Server will be closed'
  )
end

server.close