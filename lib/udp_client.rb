require "socket"
require "timeout"

module UDPClient
  @drone_udp_port = 12345

  def self.broadcast_to_potential_servers(content, udp_port)
    body = {:reply_port => @drone_udp_port, :content => content}

    s = UDPSocket.new
    s.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
    s.send(Marshal.dump(body), 0, '<broadcast>', udp_port)
    s.close
  end

  def self.start_server_listener(time_out=3, &code)
    Thread.fork do
      s = UDPSocket.new
      s.bind('0.0.0.0', @drone_udp_port)

      begin
        body, sender = timeout(time_out) { s.recvfrom(1024) }
        server_ip = sender[3]
        data = Marshal.load(body)
        code.call(data, server_ip)
        s.close
      rescue Timeout::Error
        s.close
        raise
      end
    end
  end

  def self.query_server(content, server_udp_port, time_out=3, &code)
    thread = start_server_listener(time_out) do |data, server_ip|
      code.call(data, server_ip)
    end

    broadcast_to_potential_servers(content, server_udp_port)

    begin
      thread.join
    rescue Timeout::Error
      return false
    end

    true
  end

end
