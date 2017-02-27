class TransactionOutput < ::ApplicationRecord
  belongs_to :tx, class_name: 'Transaction'
  has_many :next_inputs, foreign_key: :prev_output_key, primary_key: :output_key, class_name: 'TransactionInput'
  has_one :address, foreign_key: :value, primary_key: :address_value

  scope :spent, ->{ joins(:next_inputs) }

  before_save do
    set_address_from_pubkey_script
    self.output_key = "#{tx.tx_hash}:#{output_index}"
  end

  def set_address_from_pubkey_script
    return if address_value.present?
    self.address_value = Bitcoin::Script.new(pubkey_script.htb).get_address
  end
end
