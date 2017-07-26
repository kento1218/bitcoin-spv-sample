require_relative 'environment'

migrate_dir = 'db/migrate'

desc "initialization"
task :environment do
  load_environment
end

desc "start console"
task console: :environment do
  Pry.start
end

desc "run bitcoin node"
task run_node: :environment do
  Runner.start
end

desc "generate addresses KEYFILE="
task generate_addresses: :environment do
  Wallet.first_or_create.generate_addresses(100, ENV['KEYFILE'])
end

desc "restore addresses from KEYFILE"
task restore_addresses: :environment do
  Wallet.first_or_create.restore_addresses(ENV['KEYFILE'])
end

desc "pay to address ADDRESS, VALUE (satoshis), KEYFILE"
task pay_to_address: :environment do
  Wallet.first_or_create.pay_to_address(
    ENV['ADDRESS'], ENV['VALUE'].to_i, 2000, ENV['KEYFILE'])
end

desc "get address"
task get_address: :environment do
  address = Wallet.first_or_create.unused_addresses.order(:created_at).first
  puts address.try(&:value)
end

desc "get balance"
task get_balance: :environment do
  w = Wallet.first_or_create
  puts "balance: #{w.balance(true)}, confirmed: #{w.balance}"
  puts "received: #{w.total_received}"
  puts "sent: #{w.total_sent}"
end

desc "load blocks from raw DATAFILE"
task load_blocks: :environment do
  prev_hash = '00'*32
  height = -1

  Block.transaction do
    Zlib::GzipReader.open(ENV['DATAFILE']) do |g|
      blocks = []

      loop do
        break if g.eof?
        b = Bitcoin::P::Block.new
        b.parse_data(g.read(80))

        blk =  Block.new(block_hash: b.hash, prev_hash: b.prev_block_hex,
          timestamp: Time.at(b.time), bits: b.bits, version: b.ver,
          merkle_root: b.mrkl_root.reverse_hth, nonce: b.nonce)

        if prev_hash == blk.prev_hash
          height += 1
          blk.height = height
          blk.best_chain = true
          prev_hash = blk.block_hash
        else
          prev_hash = nil
        end

        blocks << blk
        if blocks.size >= 5000
          Block.import blocks
          blocks.clear
        end
      end

      Block.import blocks
    end
  end

end

task dump_blocks: :environment do
  Zlib::GzipWriter.open(ENV['DATAFILE']) do |g|
    Block.best_chain.order(:height).pluck(:version, :prev_hash, :merkle_root,
      :timestamp, :bits, :nonce).each do |v, p, m, t, b, n|
      g.write [v, p.htb_reverse, m.htb_reverse, t.to_i, b, n].pack("Va32a32VVV")
    end
  end
end

namespace :db do
  desc 'migrate schema'
  task migrate: :environment do
    ActiveRecord::Migrator.migrate(migrate_dir, ENV['VERSION'] ? ENV['VERSION'].to_i : nil)
  end

  desc 'rollback previous migration'
  task rollback: :environment do
    ActiveRecord::Migrator.rollback(migrate_dir, ENV['STEP'] ? ENV['STEP'].to_i : 1)
  end

  desc "create migration NAME="
  task :create_migration do
    migration_name = ENV['NAME']
    file_name = migration_name.underscore
    class_name = migration_name.camelize
    migration_file = "#{Time.now.strftime('%Y%m%d%H%M%S')}_#{file_name}.rb"
    File.open(File.expand_path(migration_file, migrate_dir), 'w') do |f|
      f.puts <<-EOS
class #{class_name} < ActiveRecord::Migration
  def change
  end
end
EOS
    end
  end
end
