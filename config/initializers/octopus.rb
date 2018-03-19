$db = Class.new
$db.class_eval do
  # 主数据库
  def self.master(&block)
    if Octopus.config[Rails.env].has_key?('master')
      Octopus.using(:master, &block)
    else
      block.call
    end
  end

  # 从数据库
  def self.slave(shard = :slave, &block)
    Octopus.using(shard, &block)
  end

  # 主数据库连接字符串信息
  def self.master_info
    Rails.configuration.database_configuration[Rails.env]
  end

  # 从数据库连接字符串信息
  def self.slave_info
    Octopus.config[Rails.env]["slave"]
  end
end

