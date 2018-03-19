require File.dirname(__FILE__) + '/lib/acts_as_task'
ActiveRecord::Base.send(:include, Redmine::Acts::Task)
