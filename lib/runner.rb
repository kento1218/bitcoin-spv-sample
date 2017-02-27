SOCKET_IO_ERRORS = [IOError, Errno::EBADF, Errno::ECONNRESET, Errno::ETIMEDOUT, Errno::EPIPE, Errno::ENETUNREACH, Errno::ECONNREFUSED]
INIT_NODES = 5

class Runner
  def self.start
    new.start
  end

  def getseeds
    addresses = []
    futures = Bitcoin.network[:dns_seeds].map do |d|
      Concurrent::Future.execute{ Resolv.getaddresses(d) }
    end
    while addresses.size < (INIT_NODES * 2)
      sleep(1)
      futures.each{|f| addresses += f.value if f.fulfilled? }
    end
    addresses.sample(INIT_NODES)
  end

  def start
    load_environment

    conn = ConnectionDealer.new
    conn.start

    getseeds.each do |host|
      conn.add_node host, Bitcoin.network[:default_port]
    end

    sleep
  rescue Interrupt
  ensure
    conn.stop if conn
  end
end
