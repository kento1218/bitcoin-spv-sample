class ConnectionDealer

  SELECT_TIMEOUT = 3
  BLOCK_CHECK_INTERVAL = 3
  PING_INTERVAL = 60

  def initialize
    @nodes = Concurrent::Array.new
    @send_queue = Concurrent::ThreadPoolExecutor.new(max_threads: 1)
    @chain_state = ChainState.new
  end

  def add_node(host, port)
    @nodes << Node.new(host, port, @send_queue)
  end

  def stop
    return unless @running

    @running = false
    @keep_alive.shutdown
    @block_checker.shutdown
    @thread.join
    @listen_thread.join
    @nodes.each{|n| n.disconnect }
  end

  def prepare_nodes
    @nodes.reject!{|n| n.status == :closed }
    @nodes.each do |node|
      if node.status == :created
        node.connect
      else
        node.verify_connection
      end
    end
  end

  def start
    return if @running

    @running = true
    @thread = Thread.new do
      while @running
        prepare_nodes

        socks = {}
        @nodes.each{|n| socks[n.socket] = n }

        begin
          selected = IO.select(socks.keys, nil, nil, SELECT_TIMEOUT)
        rescue *SOCKET_IO_ERRORS
          next
        end

        next if selected.nil?
        selected[0].each do |sock|
          socks[sock].receive
        end

        ActiveRecord::Base.connection.close
      end
    end
    @listen_thread = Thread.new do
      ApplicationRecord.listen('address', 'transaction') do |conn|
        while @running
          conn.wait_for_notify(SELECT_TIMEOUT) do |event, pid, *args|
            case event
            when 'address'
              all_active_node{|n| n.filter_load }
            when 'transaction'
              tx_hash = args.shift
              all_active_node{|n| n.publish_transaction(tx_hash) }
            end
          end
        end
      end
    end

    @keep_alive = Concurrent::TimerTask.new(execution_interval: PING_INTERVAL) do
      all_active_node{|n| n.ping }
    end
    @keep_alive.execute

    @block_checker = Concurrent::TimerTask.new(execution_interval: BLOCK_CHECK_INTERVAL) do
      last_received = Block.maximum(:created_at)
      return if last_received >= BLOCK_CHECK_INTERVAL.seconds.ago # too new, possibly receiving more

      if last_received >= @chain_state.updated_at # with new block
        @chain_state.execute
      end

      delay_threshold = 15
      if Bitcoin.network_name == :testnet3
        delay_threshold *= 2
      end
      if Block.latest_block.timestamp < delay_threshold.minutes.ago
        any_active_node{|n| n.get_blocks }
      end

      ActiveRecord::Base.connection.close
    end
    @block_checker.execute
  end

  def active_nodes
    @nodes.select{|n| n.status == :active }
  end

  def all_active_node
    active_nodes.each{|n| yield n }
  end
  def any_active_node
    active_nodes.sample.try{|n| yield n }
  end
end
