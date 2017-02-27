class Address < ::ApplicationRecord
  belongs_to :wallet

  has_many :tx_outputs, foreign_key: :address_value, primary_key: :value, class_name: 'TransactionOutput'
  has_many :tx_inputs, through: :tx_outputs, source: :next_inputs, class_name: 'TransactionInput'

  include Addressable
end
