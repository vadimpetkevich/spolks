require 'socket'
require 'colored'
require_relative '../message.rb'

def serve(s, file, clients)
  new_clients = {}
  clients.each_key do |client|
    file_seek, conf_number, timeout_expired = clients[client]
    file.seek(file_seek, IO::SEEK_SET)
    data = file.read(Package::MAX_DATA_SIZE)

    package = Package.new(data, conf_number)
    begin
      package.send(s, true, client.last, client[1])
    rescue UnknownConfNumber => unknown_conf_ex
      ready = IO.select([s], nil, nil, Package::CONF_TIMEOUT)
      s.recvfrom(Package::MAX_PACKAGE_LENGTH) unless ready.nil?
      puts format(
        'accept connection from %s',
        unknown_conf_ex.sender.to_s.blue
      )
      new_clients[unknown_conf_ex.sender] = [0, 1]
    rescue Exception => ex
      next
    end

    if file.eof?
      clients.delete(client)
    else
      clients[client] = [file_seek + data.length, conf_number + 1]
    end
  end
  clients.merge!(new_clients)
end
def multiplex(s, file)
  clients = Hash.new
  loop do
    if clients.empty?
      data, conf_number, sender = Package.receive(s, 10, false)
      puts format(
        'accept connection from %s',
        sender.to_s.blue
      )
      clients[sender] = [0, 1]
    end
    puts clients
    serve(s, file, clients)
    sleep 1
  end
end

server = UDPSocket.new
server_host, server_port = ARGV.first, Integer(ARGV.last)
server.bind(server_host, server_port)

puts format(
  'Server start on %s:%s',
  server_host.blue,
  server_port.to_s.blue
)

file = File.open('files/page.html', 'r')
file.binmode

begin
  multiplex(server, file)
rescue Exception => ex
  puts format(
    '%s. %s. %s'.red,
    ex.class,
    ex.message,
    'Server will be closed'
  )
end

file.close
server.close