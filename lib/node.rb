class Node
  attr_reader :socket
  attr_reader :status
  attr_reader :host, :port

  BUFFER_SIZE = 2_000

  def logger
    @logger ||= Logger.new("log/#{app_env}.log")
  end

  def initialize(host, port, send_queue, dealer)
    @host, @port, @send_queue, @dealer = host, port, send_queue, dealer
    @status = :created
    @parser = Bitcoin::P::Parser.new(self)
  end

  def send(payload)
    @send_queue.post do
      return if %i(created closed).include?(@status)
      begin
        @socket.send(payload, 0)
      rescue *SOCKET_IO_ERRORS
        @status = :closed
      end
    end
  end

  def receive
    return if %i(created closed).include?(@status)
    loop do
      buf = @socket.recv_nonblock(BUFFER_SIZE)
      @parser.parse(buf)
      break if buf.size < BUFFER_SIZE
    end
  rescue Errno::EAGAIN
  rescue *SOCKET_IO_ERRORS
    @status = :closed
  end

  def connect
    return unless %i(created closed).include?(@status)

    @socket = TCPSocket.open(@host, @port)
    @status = :connected
    logger.info "[#{@socket.fileno}] connected #{@host}:#{@port}"

    block = Block.latest_block.height
    ver = Bitcoin::P::Version.new(
      from: "127.0.0.1:8333", from_id: rand(0xffffffffffffffff),
      to: "#{@host}:#{@port}", block: block, relay: false, services: 0)
    send(ver.to_pkt)
  rescue *SOCKET_IO_ERRORS
    @status = :closed
  end

  def disconnect
    return if %i(created closed).include?(@status)
    fileno = @socket.fileno

    if @socket && !@socket.closed?
      @socket.close
    end
    @status = :closed

    logger.info "[#{fileno}] disconnected"
  rescue *SOCKET_IO_ERRORS
    @status = :closed
  end

  def verify_connection
    return if %i(created closed).include?(@status)
    @socket.send("", 0)
  rescue *SOCKET_IO_ERRORS
    @status = :closed
  end

  def on_version(version)
    logger.info "[#{@socket.fileno}] on version #{version.version}, #{version.user_agent}"
    send(Bitcoin::P.verack_pkt)
  end

  def on_ping(nonce)
    logger.info "[#{@socket.fileno}] on ping #{nonce}"
    send(Bitcoin::P.pong_pkt(nonce))
  end

  def on_verack
    logger.info "[#{@socket.fileno}] on verack"

    filter_load
    query_mempool

    @status = :active
  end

  def filter_load
    elements = [1000, Address.count + TransactionOutput.count].max
    filter = Bitcoin::BloomFilter.new(elements, 0.01, rand(0xfffffffff))
    Address.find_each{|a| filter.add_address(a.value) }
    TransactionOutput.includes(:tx).find_each do |o|
      filter.add_outpoint(o.tx.tx_hash, o.output_index)
    end

    payload = Bitcoin::P.pack_var_string(filter.filter)
    payload << [filter.nfunc, filter.tweak, Bitcoin::BloomFilter::BLOOM_UPDATE_ALL].pack('VVC')
    pkt = Bitcoin::P.pkt('filterload', payload)
    send(pkt)
  end

  def query_mempool
    send(Bitcoin::P.pkt('mempool', ''))
  end

  def block_locator(latest)
    blk = latest || Block.latest_block
    genesis = Bitcoin.network[:genesis_hash]

    hashes = []
    9.times do
      break if blk.blank?
      hashes << blk.block_hash
      blk = Block.find_by_height_in_best_chain(blk.height - 1)
    end

    s = 1
    loop do
      break if blk.blank?
      hashes << blk.block_hash
      blk = Block.find_by_height_in_best_chain(blk.height - s)
      s *= 2
    end

    hashes << genesis if hashes.last != genesis
    return hashes
  end

  def get_blocks(latest = nil)
    pkt = Bitcoin::P.getblocks_pkt(Bitcoin.network[:protocol_version], block_locator(latest))
    send(pkt)
  end

  def ping
    send(Bitcoin::P.ping_pkt)
  end

  def on_inv_transaction(tx_hash)
    logger.info "[#{@socket.fileno}] on inv(transaction) #{tx_hash.bth}"
    return if Transaction.where(tx_hash: tx_hash.bth).exists?
    send(Bitcoin::P.getdata_pkt(:tx, [tx_hash]))
  end

  def on_inv_block_v2(block_hash, index, total)
    logger.info "[#{@socket.fileno}] on inv(block) #{block_hash.bth}"
    return if Block.where(block_hash: block_hash.bth).exists?
    send(Bitcoin::P.getdata_pkt(:filtered_block, [block_hash]))
  end

  def on_mrkle_block(block)
    logger.info "[#{@socket.fileno}] on mrkle_block #{block.hash}, #{block.tx_hashes}"

    unless block.verify_mrkl_root
      logger.info "[#{@socket.fileno}] invalid mrkle root in #{block.hash}"
      return
    end

    Block.create_by_block(block)
  end

  def on_tx(transaction)
    logger.info "[#{@socket.fileno}] on tx #{transaction.hash}"
    # TODO: need verify?

    return unless target_tx?(transaction)
    Transaction.create_by_tx(transaction)
  end

  def target_tx?(transaction)
    out = TransactionOutput.where('1=0')
    transaction.inputs.each do |i|
      key = TransactionInput.output_key_from_input(i)
      out = out.or(TransactionOutput.where(output_key: key))
    end
    return true if out.exists?

    addresses = transaction.outputs.map do |o|
      o.parsed_script.get_address
    end
    return Address.where(value: addresses).exists?
  end

  def publish_transaction(tx_hash)
    return unless Transaction.where(tx_hash: tx_hash).exists?
    send(Bitcoin::P.inv_pkt(:tx, [tx_hash.htb]))
  end

  def on_get_transaction(tx_hash)
    logger.info "[#{@socket.fileno}] on get(transaction) #{tx_hash.bth}"
    tx = Transaction.where.not(raw_tx: nil).find_by(tx_hash: tx_hash.bth)
    if tx
      pkt = Bitcoin::P.pkt('tx', tx.raw_tx.htb)
      send(pkt)
    end
  end

  def on_get_block(block_hash)
    logger.info "[#{@socket.fileno}] on get(block) #{block_hash.bth}"
  end

  def on_addr(addr)
    logger.info "[#{@socket.fileno}] on addr #{addr.ip}"
    @dealer.add_node addr.ip, Bitcoin.network[:default_port] if @dealer
  end

  def on_pong(nonce)
    logger.info "[#{@socket.fileno}] on pong #{nonce}"
  end

  def on_reject(reject)
    logger.info "[#{@socket.fileno}] on reject #{reject}"
  end

  def on_error(*error)
    logger.info "[#{@socket.fileno}] on error #{error}"
  end
end
