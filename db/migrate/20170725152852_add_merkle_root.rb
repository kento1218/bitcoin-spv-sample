class AddMerkleRoot < ActiveRecord::Migration
  def change
    add_column :blocks, :merkle_root, :string
    add_column :blocks, :nonce, :integer, limit: 8
  end
end
