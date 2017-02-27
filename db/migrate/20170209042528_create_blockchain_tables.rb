class CreateBlockchainTables < ActiveRecord::Migration
  def change
    create_table :blocks do |t|
      t.string :block_hash
      t.string :prev_hash
      t.datetime :timestamp
      t.integer :bits
      t.integer :version
      t.integer :height
      t.boolean :best_chain
      t.timestamps null: false
    end
    add_index :blocks, [:block_hash], unique: true
    add_index :blocks, [:prev_hash]
    add_index :blocks, [:height]

    create_table :block_transactions do |t|
      t.string :block_hash
      t.string :tx_hash
      t.timestamps null: false
    end
    add_index :block_transactions, [:block_hash]
    add_index :block_transactions, [:block_hash, :tx_hash], unique: true
    add_index :block_transactions, [:tx_hash]

    create_table :transactions do |t|
      t.string :tx_hash
      t.text :raw_tx
      t.timestamps null: false
    end
    add_index :transactions, [:tx_hash], unique: true

    create_table :transaction_outputs do |t|
      t.integer :tx_id
      t.integer :output_index
      t.string :output_key
      t.integer :amount_satoshis
      t.string :pubkey_script
      t.string :address_value
      t.timestamps null: false
    end
    add_index :transaction_outputs, [:tx_id]
    add_index :transaction_outputs, [:output_key]
    add_index :transaction_outputs, [:address_value]

    create_table :transaction_inputs do |t|
      t.integer :tx_id
      t.string :prev_tx_hash
      t.integer :prev_output_index
      t.string :prev_output_key
      t.string :sig_script
      t.timestamps null: false
    end
    add_index :transaction_inputs, [:tx_id]
    add_index :transaction_inputs, [:prev_tx_hash]
    add_index :transaction_inputs, [:prev_output_key]

    create_table :addresses do |t|
      t.integer :wallet_id
      t.string :value
      t.timestamps null: false
    end
    add_index :addresses, [:wallet_id]
    add_index :addresses, [:value], unique: true

    create_table :wallets do |t|
      t.timestamps null: false
    end
  end
end
