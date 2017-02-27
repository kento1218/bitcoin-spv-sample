module Addressable
  def spent_tx_outputs
    tx_outputs.spent
  end

  def unspent_tx_outputs
    tx_outputs.where.not(id: spent_tx_outputs.pluck(:id))
  end

  def total_received
    tx_outputs.map{|o| o.amount_satoshis }.sum
  end

  def total_sent
    tx_inputs.joins(:prev_output).includes(:prev_output).map{|i| i.prev_output.amount_satoshis }.sum
  end

  def balance(include_unconfirmed = false)
    unspent_tx_outputs.includes(:tx).reduce(0) do |s, o|
      s + ((include_unconfirmed || o.tx.block.present?) ? o.amount_satoshis : 0)
    end
  end
end
