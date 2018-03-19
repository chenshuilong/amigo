# Globle $redis
$redis = Redis::Namespace.new("app", :redis => Redis.new)
$redis.instance_eval do
  def fetch(*args, **options, &block)
    command = args.shift
    obj     = args.pop

    if obj.respond_to?(:updated_on)
      cache_key = "#{obj.id}-#{obj.updated_on.to_i}"
    elsif obj.respond_to?(:updated_at)
      cache_key = "#{obj.id}-#{obj.updated_at.to_i}"
    else
      cache_key = obj
    end

    args = args << cache_key
    result  = send(command.to_sym, *args)
    if result
      result.html_safe
    elsif block_given?
      result = block.call args
      expire args.first, (options[:expire] || 2.hours.to_i)
      result
    end
  end
end

# config/initializers/session_store.rb
RedmineApp::Application.config.session_store :redis_store, {
  servers: [
    {
      host: "localhost",
      port: 6379,
      db: 0,
      namespace: "session"
    },
  ],
  expire_after: 1.days,
  key: "_amigo_session"
}