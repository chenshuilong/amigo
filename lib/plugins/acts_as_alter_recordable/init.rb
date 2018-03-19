require File.dirname(__FILE__) + '/lib/acts_as_recordable'
ActiveRecord::Base.send(:include, Redmine::Acts::Recordable)
