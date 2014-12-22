require 'socket'
begin
server = Socket.new Socket::PF_INET, Socket::SOCK_STREAM

# Returns an addrinfo object for TCP address.

local_addrinfo = Addrinfo.tcp "localhost", 27015
# Binds to the given local address.
begin
  server.bind local_addrinfo

  rescue Errno::EADDRINUSE => error
    print "Error of the socket bind. "
    puts error.message
    exit 1
end

# Listens for connections, using the specified int as the maximum length of the queue for pending connections.
server.listen 5
puts "Server waits for connections..."

client, client_addr_info = server.accept
puts "Accepted connection from #{client_addr_info.ip_address}"

def receive_all_data client
  all_data = ""
  retry_flag = true

  loop do
    begin
      receive_data = client.recvfrom_nonblock 10
      rescue IO::EAGAINWaitReadable
        retry if retry_flag
        return all_data
      else
        all_data << receive_data[0]
        retry_flag = false
    end
  end
end

loop do
  message = receive_all_data client
  break if message[/By$/]
  print "Client: " << message
  client.puts "Current time is #{Time::now}"
end

server.close