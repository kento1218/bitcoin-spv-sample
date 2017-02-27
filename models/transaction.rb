class Transaction < ::ApplicationRecord
  has_one :block_transaction, foreign_key: :tx_hash, primary_key: :tx_hash
  has_one :block, ->() { merge(Block.best_chain) }, through: :block_transaction

  has_many :outputs, foreign_key: :tx_id, class_name: 'TransactionOutput'
  has_many :inputs, foreign_key: :tx_id, class_name: 'TransactionInput'

  after_commit :notify_new_tx

  def notify_new_tx
    return if raw_tx.blank?
    self.class.notify("transaction, '#{self.tx_hash}'")
  end

  def self.create_by_tx(t, save_rawtx = false)
    tx = find_or_initialize_by(tx_hash: t.hash)
    return tx if tx.persisted?

    transaction do
      tx.raw_tx = t.to_payload.bth if save_rawtx
      tx.save
      t.inputs.each do |i|
        tx.inputs.create(prev_tx_hash: i.prev_out_hash.reverse_hth,
          prev_output_index: i.prev_out_index, sig_script: i.script_sig.bth)
      end
      t.outputs.each_with_index do |o, idx|
        tx.outputs.create(output_index: idx, amount_satoshis: o.value, pubkey_script: o.pk_script.bth)
      end
    end

    return tx
  end
end
