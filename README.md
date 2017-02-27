# Bitcoin SPV Sample
SPVノードのサンプル的な実装です。以下のことができます。

* Walletの作成
* Wallet宛のTransactionの取得
* Blockヘッダの受信
* Walletから出金

## Notice
あくまでサンプルなので、mainnetでの利用は想定していません。Bitcoinの紛失等が起きても責任は負いません。

# Requirement
* Ruby
* PostgreSQL

# Getting Started

## Setup
```
$ git clone https://github.com/kento1218/bitcoin-spv-sample.git
$ bundle install
$ createdb spvsample_development
$ bundle exec rake db:migrate
```

## Bootstrap
BlockをGenesisから取得すると遅いので、Blockヘッダを固めたファイルをロードします。

1. https://bht-tech.net/bitcoin/blocks-test.bin.gz からtestnet用Blockヘッダをダウンロード
1. `$ bundle exec rake load_blocks DATAFILE="blocks-test.bin.gzのパス"` を実行（約１０分程度かかります）

# Usage

## Start Node
```
$ bundle exec rake run_node &
```

## Initialize Wallet
```
$ bundle exec rake generate_addresses KEYFILE="どこか安全なパス"
```

を実行すると、アドレスを100個生成し、秘密鍵を指定したファイルへ保存します。鍵ファイルは管理に注意してください。

## Receive Payment
```
$ bundle exec rake get_address
```

を実行すると、未使用のアドレスを１つ表示します。

## Show Balance
```
$ bundle exec rake get_balance
```

## Send Payment
```
$ bundle exec rake pay_to_address ADDRESS="送り先アドレス" VALUE="金額 (satoshi)" KEYFILE="保存した鍵ファイル"
```

を実行すると、ウォレットから送金できます。
