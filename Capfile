require 'capistrano/setup'
require 'capistrano/deploy'
require 'capistrano/rbenv'
require 'capistrano/rails'
require 'capistrano/sidekiq'
require 'whenever/capistrano'
# require 'capistrano/puma'
# require 'capistrano/scm/git'

# install_plugin Capistrano::SCM::Git

# install_plugin Capistrano::Puma  # Default puma tasks
# install_plugin Capistrano::Puma::Workers  # if you want to control the workers (in cluster mode)
# install_plugin Capistrano::Puma::Jungle # if you need the jungle tasks
# install_plugin Capistrano::Puma::Monit  # if you need the monit tasks
# install_plugin Capistrano::Puma::Nginx  # if you want to upload a nginx site template

Dir.glob('lib/capistrano/tasks/*.cap').each { |r| import r }
