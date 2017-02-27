class BlockTransaction < ::ApplicationRecord
  belongs_to :block, foreign_key: :block_hash, primary_key: :block_hash, required: false
  belongs_to :tx, foreign_key: :tx_hash, primary_key: :tx_hash, class_name: 'Transaction', required: false
end
