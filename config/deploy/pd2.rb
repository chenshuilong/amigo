set :stage, :production
set :whenever_roles, ->{ [:pd2] }

server '18.8.5.9', user: 'cenx', roles: %w{pd2 web app db}

# Disabled whenever
Rake::Task["whenever:update_crontab"].clear_actions

