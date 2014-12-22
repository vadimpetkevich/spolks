require 'socket'
require 'colored'
require_relative '../message.rb'

def get_file(s, file)
  current_conf_number = 1
  loop do
    broken_package_count = 0

    begin
      data, conf_number = Package.receive(s, 20, true)
    rescue BrokenPackageException => broken_package_exception
      broken_package_count += 1
      retry unless broken_package_count > 5
      raise broken_package_exception
    else
      puts 'Recv package ' + conf_number.to_s.green
    end

    if current_conf_number == conf_number
      file.write(data)
      current_conf_number += 1
    end
  end
end

client = UDPSocket.new
client_host, client_port = ARGV.first, Integer(ARGV[1])
client.bind(client_host, client_port)
server_host, server_port = ARGV[2], Integer(ARGV.last)

puts format(
  'Client start on %s:%s. Client is gonna connect to %s:%s',
  client_host.blue,
  client_port.to_s.blue,
  server_host.blue,
  server_port.to_s.blue
)

file = File.open('files/page.html', 'w')
file.binmode

begin
  Package.new('', 0).send(client, false, server_host, server_port)
  get_file(client, file)
rescue Exception => ex
  puts format(
    '%s. %s. %s'.red,
    ex.class,
    ex.message,
    'Client will be closed'
  )
end

file.close
client.close