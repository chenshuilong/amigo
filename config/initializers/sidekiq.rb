Sidekiq.configure_server do |config|
  config.redis = { url: 'redis://localhost:6379/0' }

  # 控制获取任务的方式
  # 这里是平均 5 秒才去抓去一次任务
  config.average_scheduled_poll_interval = 5
end

Sidekiq.configure_client do |config|
  config.redis = { url: 'redis://localhost:6379/0' }
end

Sidekiq.remove_delay!
