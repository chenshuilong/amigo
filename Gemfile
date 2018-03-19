source 'https://rubygems.org'

if Gem::Version.new(Bundler::VERSION) < Gem::Version.new('1.5.0')
  abort "Redmine requires Bundler 1.5.0 or higher (you're using #{Bundler::VERSION}).\nPlease update with 'gem update bundler'."
end

gem "rails", "4.2.6"
gem 'coffee-rails', '~> 4.1.0'
gem "coderay", "~> 1.1.0"
gem "builder", ">= 3.0.4"
gem "request_store", "1.0.5"
gem "mime-types", (RUBY_VERSION >= "2.0" ? "~> 3.0" : "~> 2.99")
gem "protected_attributes"
gem "actionpack-action_caching"
gem "actionpack-xml_parser"
gem "roadie-rails"
gem "mimemagic"
gem "jquery-rails", "~> 3.1.4"
gem 'jquery-ui-rails'

#### For Gionee Development

gem 'rubycas-client', :git => 'git://github.com/rubycas/rubycas-client.git'
gem "haml-rails", "~> 0.9"
gem 'sass-rails'
gem 'roo' # Excel, CSV, OpenOffice, GoogleSpreadSheet
gem 'uglifier', '2.5.3'
gem 'font-awesome-sass', '~> 4.7.0'
gem 'ruby-pinyin' # https://github.com/janx/ruby-pinyin
gem 'httparty' # Parse Json from URL or API
gem 'whenever', :require => false # Task Scheduler
gem 'browser' # Check browser
gem 'gemoji' # Gemoji
gem 'jenkins_api_client', :require => false # Jenkins Api
gem 'rails_autolink' # Auto link url in text
gem 'exception_handler' # Web 4xx/5xx error handler
gem 'vuejs-rails' # Vue.js
gem 'git' # Provide Git commands support
gem 'rubyzip' # To zip or unzip files
gem 'carrierwave', '~> 1.0' # Crop image
gem 'sambal' # Download files via smbclient, https://github.com/johnae/sambal
gem 'aasm' # Ruby state machine / workflow
gem 'ar-octopus' # Rails database write and read split, https://github.com/thiagopradi/octopus
gem 'pundit' # Globle permissions control

# Redis
gem 'redis', '~>3.2' # Redis
gem 'redis-rails'
gem 'redis-namespace'
# gem 'redis-rack-cache'

# Export Excel
gem 'axlsx'
gem 'axlsx_rails'

# Background Task
gem 'sidekiq'
gem 'sidekiq-limit_fetch' # https://github.com/brainopia/sidekiq-limit_fetch
gem 'sinatra'
gem 'newrelic_rpm' # Rails moniter
gem 'show_code'

# Open4
gem 'open4'

# Puma Web Server
gem 'puma'

group :development do
  gem "erb2haml"
  gem "hirb"
  gem 'hirb-unicode'
  gem 'pry-rails'
  gem 'pry-doc'
  gem 'pry-byebug'
  gem 'pry-stack_explorer'
  gem 'better_errors'
  gem 'capistrano-sidekiq' # Sidekiq deploy gem
  gem 'capistrano-rails'
  gem 'capistrano-rbenv'
  gem 'capistrano',         require: false
  gem 'capistrano-rvm',     require: false
  gem 'capistrano-rails',   require: false
  gem 'capistrano-bundler', require: false
  gem 'capistrano3-puma',   require: false
  gem 'rack-mini-profiler', require: false # Analysis time of page loading
  gem 'awesome_print'
end


#####

# Request at least nokogiri 1.6.7.2 because of security advisories
gem "nokogiri", ">= 1.6.7.2"

# Request at least rails-html-sanitizer 1.0.3 because of security advisories
gem "rails-html-sanitizer", ">= 1.0.3"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :x64_mingw, :mswin, :jruby]
gem "rbpdf", "~> 1.19.0"

# Optional gem for LDAP authentication
group :ldap do
  gem "net-ldap", "~> 0.12.0"
end

# Optional gem for OpenID authentication
group :openid do
  gem "ruby-openid", "~> 2.3.0", :require => "openid"
  gem "rack-openid"
end

platforms :mri, :mingw, :x64_mingw do
  # Optional gem for exporting the gantt to a PNG file, not supported with jruby
  group :rmagick do
    gem "rmagick", ">= 2.14.0"
  end

  # Optional Markdown support, not for JRuby
  group :markdown do
    gem "redcarpet", "~> 3.3.2"
  end
end

platforms :jruby do
  # jruby-openssl is bundled with JRuby 1.7.0
  gem "jruby-openssl" if Object.const_defined?(:JRUBY_VERSION) && JRUBY_VERSION < '1.7.0'
  gem "activerecord-jdbc-adapter", "~> 1.3.2"
end

# Include database gems for the adapters found in the database
# configuration file
require 'erb'
require 'yaml'
database_file = File.join(File.dirname(__FILE__), "config/database.yml")
if File.exist?(database_file)
  database_config = YAML::load(ERB.new(IO.read(database_file)).result)
  adapters = database_config.values.map {|c| c['adapter']}.compact.uniq
  if adapters.any?
    adapters.each do |adapter|
      case adapter
        when 'mysql2'
          gem "mysql2", "~> 0.3.11", :platforms => [:mri, :mingw, :x64_mingw]
          gem "activerecord-jdbcmysql-adapter", :platforms => :jruby
        when 'mysql'
          gem "activerecord-jdbcmysql-adapter", :platforms => :jruby
        when /postgresql/
          gem "pg", "~> 0.18.1", :platforms => [:mri, :mingw, :x64_mingw]
          gem "activerecord-jdbcpostgresql-adapter", :platforms => :jruby
        when /sqlite3/
          gem "sqlite3", :platforms => [:mri, :mingw, :x64_mingw]
          gem "jdbc-sqlite3", ">= 3.8.10.1", :platforms => :jruby
          gem "activerecord-jdbcsqlite3-adapter", :platforms => :jruby
        when /sqlserver/
          gem "tiny_tds", "~> 0.6.2", :platforms => [:mri, :mingw, :x64_mingw]
          gem "activerecord-sqlserver-adapter", :platforms => [:mri, :mingw, :x64_mingw]
        else
          warn("Unknown database adapter `#{adapter}` found in config/database.yml, use Gemfile.local to load your own database gems")
      end
    end
  else
    warn("No adapter found in config/database.yml, please configure it first")
  end
else
  warn("Please configure your config/database.yml first")
end

group :development do
  gem "rdoc", ">= 2.4.2"
  gem "yard"
end

group :test do
  gem "minitest"
  gem "rails-dom-testing"
  gem "mocha"
  gem "simplecov", "~> 0.9.1", :require => false
  # For running UI tests
  gem "capybara"
  gem "selenium-webdriver"
end

local_gemfile = File.join(File.dirname(__FILE__), "Gemfile.local")
if File.exists?(local_gemfile)
  eval_gemfile local_gemfile
end

# Load plugins' Gemfiles
Dir.glob File.expand_path("../plugins/*/{Gemfile,PluginGemfile}", __FILE__) do |file|
  eval_gemfile file
end