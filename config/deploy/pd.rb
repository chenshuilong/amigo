set :stage, :production
set :whenever_roles, ->{ [:pd, :app] }

server '18.8.5.8', user: 'cenx', roles: %w{pd web app db}

namespace :deploy do
  desc "Update crontab with whenever"
  task :update_cron do
    on roles(:app) do
      within current_path do
        execute :bundle, :exec, "whenever --update-crontab #{fetch(:application)}"
      end
    end
  end

  after :finishing, 'deploy:update_cron'
end
