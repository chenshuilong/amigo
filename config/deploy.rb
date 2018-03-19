set :application, "amigo"

set :repo_url, -> { "ssh://amige@19.9.0.146:29418/Amige" }
# set :repo_url, -> { "git@bitbucket.org:Cenx/gionee.git" }

set :branch, ENV['branch'] || 'master'
set :deploy_to, -> { "/var/www/amigo" }

set :user, "cenx"

set :puma_bind,       "unix://#{shared_path}/tmp/sockets/#{fetch(:application)}-puma.sock"
set :puma_state,      "#{shared_path}/tmp/pids/puma.state"
set :puma_pid,        "#{shared_path}/tmp/pids/puma.pid"
set :puma_access_log, "#{release_path}/log/puma.error.log"
set :puma_error_log,  "#{release_path}/log/puma.access.log"
set :ssh_options,     { forward_agent: true, user: fetch(:user), keys: %w(~/.ssh/id_rsa.pub) }
set :puma_preload_app, true
set :puma_worker_timeout, nil
set :puma_init_active_record, true  # Change to false when not using ActiveRecord

set :rbenv_path, '/home/cenx/.rbenv'
set :rbenv_type, :user
set :rbenv_ruby, '2.3.1'

set :assets_roles, [:web, :app]
set :keep_assets, 2

set :linked_dirs, fetch(:linked_dirs, []).push('log', 'files', 'tmp', 'vendor/bundle', 'public/system', 'public/uploads')
set :linked_files, fetch(:linked_files, []).push('config/database.yml', 'config/secrets.yml', 'tmp/restart.txt', 'config/configuration.yml', 'config/environment.rb', 'config/shards.yml')

set :pty, false

set :sidekiq_config, -> { File.join(release_path, 'config', 'sidekiq.yml') }
# set :sidekiq_config, -> { File.join(release_path, 'config', 'sidekiq_high.yml') }
# set :sidekiq_config, -> { File.join(release_path, 'config', 'sidekiq_middle.yml') }
# set :sidekiq_config, -> { File.join(release_path, 'config', 'sidekiq_low.yml') }

namespace :deploy do
  desc "Restart application"
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      execute :touch, release_path.join("tmp/restart.txt")
    end
  end

  # after deploy:migrate, :plugin_assets do
  #   on roles(:app) do
  #     within release_path do
  #       with rails_env: fetch(:rails_env) do
  #         # Copy over plugin assets
  #         execute :rake, 'redmine:plugins:assets'
  #         # Run plugin migrations
  #         execute :rake, 'redmine:plugins:migrate'
  #       end
  #     end
  #   end
  # end

  after 'deploy:publishing', 'deploy:restart'
end
