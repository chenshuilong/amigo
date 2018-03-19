
# unless ['18.8.10.210', '18.8.5.8', '18.8.5.9'].include?(Socket.ip_address_list[1].ip_address)

if Rails.env.development?
  begin
    require 'rack-mini-profiler'
    # initialization is skipped so trigger it
    Rack::MiniProfilerRails.initialize!(Rails.application)
  rescue LoadError
    Rails.logger.warn "Load rack-mini-profiler Error"
  end
end

