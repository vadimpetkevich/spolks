require_relative '../message.rb'

def new_thread(host, port)
  Thread.new(port) do |port|
    Thread.stop
    client = Thread.current[:client]
    server = UDPSocket.new
    begin
      server.bind(host, port)
    rescue Errno::EADDRINUSE
      port += Random.rand(0..5)
      retry
    else
      puts format(
               'New thread %s has started on %s:%s',
               Thread.current,
               host.blue,
               port.to_s.blue
           )
    end


    file = File.open('files/page.html', 'r')
    file.binmode

    conf_number = 1
    begin
      data = file.read(Package::MAX_DATA_SIZE)
      package = Package.new(data, conf_number)

      conf_failed_count = 0
      begin
        package.send(server, true, client.last, client[1])
      rescue Exception => confirm_failed_exception
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
    server.close
  end
end
def multithreading(s, server_host, server_port)
  sleeping_threads = []
  threads = []

  2.times() do
    sleeping_threads << new_thread(server_host, server_port + 1)
  end
  sleeping_threads.each() { |thread| sleep 0.1 until thread.status == 'sleep' }

  loop do
    begin
      data, conf_number, sender = Package.receive(s, 10, false)
      threads.each {|thread| thread.kill if thread[:client] == sender}
      threads.select! { |thread| thread.alive? }
    rescue Exception => ex
      retry
    end

    if sleeping_threads.empty?
      if threads.count < 3
        threads << new_thread(server_host, server_port + 1)

        threads.last[:client] = sender
        sleep 0.1 until threads.last.status == 'sleep'
        threads.last.run
      else
        puts format(
               'Ignored connection from %s',
               sender.to_s.blue
             )
      end
    else
      sleeping_threads.first[:client] = sender
      sleeping_threads.first.run
      threads << sleeping_threads.first
      sleeping_threads.shift
    end
  end
end