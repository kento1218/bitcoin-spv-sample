class AddValidatedOnBlocks < ActiveRecord::Migration
  def up
    add_column :blocks, :validated, :boolean

    if Bitcoin.network_name == :bitcoin
      # mark as validated before UAHF
      execute <<-SQL
        update blocks set validated = true where height < 478559
      SQL
    else
      execute <<-SQL
        update blocks set validated = true
      SQL
    end
  end
  def down
    remove_column :blocks, :validated
  end
end
