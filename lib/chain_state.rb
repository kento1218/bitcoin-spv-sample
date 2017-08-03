class ChainState
  BCASH_GENESIS_HASH = '000000000000000000651ef99cb9fcbe0dadde1d424bd9f15ff20136191a5eec'

  attr_accessor :updated_at

  def initialize
    @updated_at = Time.at(0)
  end

  def execute
    Block.transaction do
      calc_height
      update_best_chain
    end
    @updated_at = Time.now
  end

  def calc_height
    pendings = Set.new
    seeds = Set.new

    target = Block.where(height: nil).or(Block.where(validated: nil))
    target.pluck(:block_hash, :prev_hash).each do |h, prev|
      pendings << h
      seeds << prev
    end
    seeds -= pendings
    seeds = seeds.map{|h| Block.find_by(block_hash: h) }

    pendings.clear
    GC.start

    while !seeds.empty?
      parent = seeds.first
      seeds.delete(parent)
      next if parent.blank? || parent.height.blank?

      parent.next_blocks.each do |blk|
        # TODO: check blk.bits to ensure valid difficulty

        if !parent.validated
          validated = false
        elsif (Bitcoin.network_name == :bitcoin && blk.block_hash == BCASH_GENESIS_HASH)
          validated = false
        else
          validated = true
        end

        blk.update(height: parent.height + 1, validated: validated)
        seeds << blk
      end
    end

    return
  end

  def update_best_chain
    blk = Block.latest_block
    while !blk.best_chain
      blk.update(best_chain: true)
      Block.where(height: blk.height).where.not(block_hash: blk.block_hash).update_all(best_chain: false)
      blk = blk.dup.prev_block
    end
  end
end
