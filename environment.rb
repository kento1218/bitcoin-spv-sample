require 'rake'
require 'yaml'

def app_env
  ENV['APP_ENV'] || 'development'
end

Bundler.require(:default, app_env)

unless app_env == 'production'
  Bitcoin.network = :testnet3
end

def load_environment
  db_config = 'config/database.yml'
  config = YAML.load_file(db_config)
  raise "db configuration not found" unless config[app_env]

  ActiveRecord::Base.logger = Logger.new("log/#{app_env}.log")
  ActiveRecord::Base.establish_connection(config[app_env])
end

%w(models models/concerns lib).each do |dir|
  ActiveSupport::Dependencies.autoload_paths << dir
end
