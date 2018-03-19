# encoding: utf-8
#
# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

module UsersHelper
  def users_status_options_for_select(selected)
    user_count_by_status = User.group('status').count.to_hash
    options_for_select([[l(:label_all), ''],
                        ["#{l(:status_active)} (#{user_count_by_status[1].to_i})", '1'],
                        ["#{l(:status_registered)} (#{user_count_by_status[2].to_i})", '2'],
                        ["#{l(:status_locked)} (#{user_count_by_status[3].to_i})", '3']], selected.to_s)
  end

  def user_mail_notification_options(user)
    user.valid_notification_options.collect {|o| [l(o.last), o.first]}
  end

  def change_status_link(user)
    url = {:controller => 'users', :action => 'update', :id => user, :page => params[:page], :status => params[:status], :tab => nil}

    if user.locked?
      link_to l(:button_unlock), url.merge(:user => {:status => User::STATUS_ACTIVE}), :method => :put, :class => 'icon icon-unlock'
    elsif user.registered?
      link_to l(:button_activate), url.merge(:user => {:status => User::STATUS_ACTIVE}), :method => :put, :class => 'icon icon-unlock'
    elsif user != User.current
      link_to l(:button_lock), url.merge(:user => {:status => User::STATUS_LOCKED}), :method => :put, :class => 'icon icon-lock'
    end
  end

  def additional_emails_link(user)
    if user.email_addresses.count > 1 || Setting.max_additional_emails.to_i > 0
      link_to user_email_addresses_path(@user), :class => 'btn btn-primary btn-sm', :remote => true do
        icon('plus') + "&nbsp;".html_safe +
        l(:label_email_address_plural)
      end
    end
  end

  def user_settings_tabs
    tabs = [{:name => 'general', :partial => 'users/general', :label => :label_general},
            {:name => 'memberships', :partial => 'users/memberships', :label => :label_project_plural}
           ]
    if Group.givable.any?
      tabs.insert 1, {:name => 'groups', :partial => 'users/groups', :label => :label_group_plural}
    end
    tabs
  end

  def user_to_json(users)
    map_users = users.map do |user|
      {
        :id => user.id,
        :name => user.firstname,
        :type => user.class.name.downcase
      }
    end

    map_users.unshift({
      :id => (params[:project_id].present?? User.current.id : "me"),
      :name => "<< #{l(:label_me)} >>",
      :type => User.current.class.name.downcase
    }) if User.current.logged? && users.find_by(:id => User.current.id).present? && (params[:withme].present? && params[:withme] == "true")

    map_users
  end

  def render_user_tab_content
    case @tab
      when 'pass'
        render :partial => 'users/tabs/pass'
      when 'notification'
        content_tag(:div, l(:field_mail_notification), :class => 'label') +
        render(:partial => 'users/mail_notifications')
      when 'preference'
        content_tag(:div, l(:label_preferences), :class => 'label') +
        render(:partial => 'users/preferences')
      when 'token'
        render(:partial => 'users/tabs/token')
      else
        render :partial => 'users/tabs/info'
    end
  end

end
