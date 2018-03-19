set :stage, :test
set :whenever_roles, ->{ [:tt] }

server 'dev.os.gionee.com:22', user: 'cenx', roles: %w{web app db}

# Disabled whenever
Rake::Task["whenever:update_crontab"].clear_actions
