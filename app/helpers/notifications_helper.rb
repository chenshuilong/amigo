module NotificationsHelper

  def notification_tabs
    tabs = [
            {:name => 'condition', :partial => 'notifications/tabs/condition', :label => :notification_received_condition},
            {:name => 'system', :partial => 'notifications/tabs/system', :label => :notification_received_system},
            {:name => 'report', :partial => 'notifications/tabs/report', :label => :notification_received_report},
            {:name => 'mission', :partial => 'notifications/tabs/mission', :label => :notification_received_mission},
           ]
  end

  def selected_tab(selected=params[:tab])
    tabs = notification_tabs
    selected = tabs.detect {|tab| tab[:name] == selected} || tabs.first
  end

  def render_handle_result(notification)
    if notification.accepted?
      if notification.category.to_s == "mission"
        content_tag :p, link_to("前往收集版本", notification.content)
      else
        content_tag :p, "你已经接受该筛选条件，可前往筛选器，我的自定义中查看。"
      end
    elsif notification.refused?
      content_tag :p, "你已拒绝接受该筛选条件。"
    elsif notification.ignored?
      content_tag :p, "你已忽略该筛选条件。"
    elsif notification.invalid?
      content_tag :p, "本消息已经失效了。"
    else
      link_to(l(:notification_accept), handle_notification_path(notification, :do => "accept"), :class => "btn btn-default btn-xs", :method => :post, :remote => true) +
      link_to(l(:notification_refuse), handle_notification_path(notification, :do => "refuse"), :class => "btn btn-default btn-xs", :method => :post, :remote => true) +
      link_to(l(:notification_ignore), handle_notification_path(notification, :do => "ignore"), :class => "btn btn-default btn-xs", :method => :post, :remote => true)
   end
  end

end
