class Block < ::ApplicationRecord
  has_one :prev_block, foreign_key: :block_hash, primary_key: :prev_hash, class_name: 'Block'
  has_many :next_blocks, foreign_key: :prev_hash, primary_key: :block_hash, class_name: 'Block'

  has_many :block_transactions, foreign_key: :block_hash, primary_key: :block_hash
  has_many :txs, through: :block_transactions, source: :tx

  scope :best_chain, ->(){ where(best_chain: true) }

  def self.find_by_height_in_best_chain(height)
    best_chain.find_by(height: height)
  end

  def self.latest_block
    where.not(height: nil).order(:height).last
  end

  def self.create_by_block(block)
    find_or_create_by(block_hash: block.hash) do |b|
      b.prev_hash = block.prev_block_hex
      b.timestamp = Time.at(block.time)
      b.bits = block.bits
      b.version = block.ver
      b.nonce = block.nonce
      b.merkle_root = block.mrkl_root.reverse_hth
    end
    block.tx_hashes.each do |tx_hash|
      BlockTransaction.find_or_create_by(block_hash: block.hash, tx_hash: tx_hash)
    end
  end
end
