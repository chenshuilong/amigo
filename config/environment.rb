# Load the Rails application
require File.expand_path('../application', __FILE__)


# Make sure there's no plugin in vendor/plugin before starting
vendor_plugins_dir = File.join(Rails.root, "vendor", "plugins")
if Dir.glob(File.join(vendor_plugins_dir, "*")).any?
  $stderr.puts "Plugins in vendor/plugins (#{vendor_plugins_dir}) are no longer allowed. " +
                   "Please, put your Redmine plugins in the `plugins` directory at the root of your " +
                   "Redmine directory (#{File.join(Rails.root, "plugins")})"
  exit 1
end

# Initialize the Rails application
Rails.application.initialize!

require 'casclient'
require 'casclient/frameworks/rails/filter'
# enable detailed CAS logging for easier troubleshooting
CASClient::Frameworks::Rails::Filter.configure(
    :cas_base_url => "http://auth.go.gionee.com",
    :logout_url => "http://auth.go.gionee.com/cas/logout",
    :service => "http://127.0.0.1:3000/login"
)