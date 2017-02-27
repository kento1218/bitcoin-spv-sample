class Wallet < ApplicationRecord
  has_many :addresses

  has_many :tx_outputs, through: :addresses, class_name: 'TransactionOutput'
  has_many :tx_inputs, through: :addresses, class_name: 'TransactionInput'
  has_many :used_addresses, ->{ distinct }, through: :tx_outputs, source: :address, class_name: 'Address'

  include Addressable
  include Bitcoin::Builder

  def unused_addresses
    addresses.where.not(id: used_addresses.pluck(:id))
  end

  def pay_to_address(address, value, fee, keyfile)
    collected = []
    input_amount = 0
    unspent_tx_outputs.each do |o|
      collected << o
      input_amount += o.amount_satoshis
      break if input_amount >= (value + fee)
    end
    raise "insufficient balance" if input_amount < (value + fee)

    keys = {}
    File.readlines(keyfile).each do |line|
      key = Bitcoin::Key.from_base58(line.chomp)
      keys[key.addr] = key
    end

    change = input_amount - (value + fee)
    change_address = unused_addresses.sample
    raise "cannot set change address; please generate_addresses first" if change > 0 && change_address.blank?

    tx = build_tx do |t|
      collected.each do |po|
        key = keys[po.address_value]
        raise "private key for #{po.address_value} not found" unless key

        t.input do |i|
          i.prev_out po.tx.tx_hash, po.output_index, po.pubkey_script.htb
          i.signature_key key
        end
      end
      t.output do |o|
        o.to address
        o.value value
      end
      if change > 0
        t.output do |o|
          o.to change_address.value
          o.value change
        end
      end
    end

    Transaction.create_by_tx(tx, true)
  end

  def generate_addresses(count, keyfile)
    keys = []
    count.times do
      addr, key = Bitcoin.generate_address
      keys << Bitcoin::Key.new(key, nil, compressed: false).to_base58
      addresses.build(value: addr)
    end
    File.open(keyfile, 'a'){|f| keys.each{|k| f.puts k }}
    save!
    self.class.notify("address")
  end

  def restore_addresses(keyfile)
    File.readlines(keyfile).each do |line|
      key = Bitcoin::Key.from_base58(line.chomp)
      addresses.build(value: key.addr)
    end
    save!
  end
end
