# Temp limit certain user

# ApplicationController.class_eval do
#   def temp_dendy_access
#     # 项目-外包开发(华勤)
#     render_403 if User.current.groups.find_by(:users => {:lastname => "项目-外包开发(华勤)"})
#   end

#   def temp_dendy_access_project
#     return true unless User.current.groups.find_by(:users => {:lastname => "项目-外包开发(华勤)"})
#     render_403 if @project.nil? || @project.users.where("users.id = ?", User.current.id).blank?
#   end

# end

# # dendy_items

# directly_dendy_config = [
#   {:controller => 'Productions'},
#   {:controller => 'Repos'},
#   {:controller => 'FasterNew'},
#   {:controller => 'VersionReleases'},
#   {:controller => 'PeriodicVersions'},
#   {:controller => 'Reports'},
#   {:controller => 'VersionPublishes'},
#   {:controller => 'My', :only => [:staffs, :links]}
# ]

# project_dendy_config = [
#   {:controller => 'Issues', :only => [:index]},
#   {:controller => 'Versions', :only => [:index, :jenkins]},
#   {:controller => 'MokuaiOwnners', :only => [:index]},
#   {:controller => 'Specs', :only => [:list, :compare]},
#   {:controller => 'Activities', :only => [:index]}
# ]

# {:temp_dendy_access => directly_dendy_config, :temp_dendy_access_project => project_dendy_config}.each do |method, configs|
#   configs.each do |config|
#     controller = "#{config[:controller]}Controller".constantize
#     controller.class_eval do
#       if config[:only].present?
#         before_action method, :only => config[:only]
#       elsif config[:except].present?
#         before_action method, :except => config[:except]
#       else
#         before_action method
#       end
#     end
#   end
# end


# # Limit users project shows

# Project.class_eval do
#   singleton_class.send(:alias_method, :old_visible, :visible)
#   scope :visible, lambda {|*args|
#     if User.current.groups.find_by(:users => {:lastname => "项目-外包开发(华勤)"})
#       where(:id => User.current.projects.ids).old_visible(*args)
#     else
#       old_visible(*args)
#     end
#   }
# end


# # Limit issues system conditions

# IssuesController.class_eval do
#   private def check_condition_id
#     return true if params[:condition_id].blank?
#     condition = Condition.find_by_id(params[:condition_id])
#     if condition.present? && condition.user == User.current && [3,4].exclude?(condition.category.to_i)
#       return true
#     elsif User.current.groups.find_by(:users => {:lastname => "项目-外包开发(华勤)"}).blank? && condition.category.to_i == 2
#       return true
#     else
#       deny_access
#     end
#   end
# end
