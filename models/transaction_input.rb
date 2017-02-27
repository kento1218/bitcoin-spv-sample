class TransactionInput < ::ApplicationRecord
  belongs_to :tx, class_name: 'Transaction'
  has_one :prev_output, foreign_key: :output_key, primary_key: :prev_output_key, class_name: 'TransactionOutput'

  before_save do
    self.prev_output_key = "#{prev_tx_hash}:#{prev_output_index}"
  end

  def self.output_key_from_input(input)
    h, i = input.prev_out_hash.reverse_hth, input.prev_out_index
    return "#{h}:#{i}"
  end
end
