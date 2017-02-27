class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def self.notify(sql)
    raise "notify not supported for #{connection.adapter_name}" if connection.adapter_name != 'PostgreSQL'
    connection.execute("notify #{sql}")
  end

  def self.listen(*events)
    raise "notify not supported for #{connection.adapter_name}" if connection.adapter_name != 'PostgreSQL'
    events.each do |ev|
      connection.execute("listen #{ev}")
    end

    yield connection.raw_connection
  ensure
    events.each do |ev|
      connection.execute("unlisten #{ev}")
    end
  end
end
