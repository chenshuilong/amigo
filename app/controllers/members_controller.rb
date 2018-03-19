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

class MembersController < ApplicationController
  model_object Member
  before_filter :find_model_object, :except => [:index, :new, :create, :autocomplete, :users, :members, :roles]
  before_filter :find_project_from_association, :except => [:index, :new, :create, :autocomplete, :users, :group_members, :members, :roles]
  before_filter :find_project_by_project_id, :only => [:index, :new, :create, :autocomplete, :users, :group_members, :members, :roles]
  before_filter :authorize, :except => [:fetch, :users, :group_members]
  accept_api_auth :index, :show, :create, :update, :destroy

  require_sudo_mode :create, :update, :destroy

  def index
    scope = @project.memberships.active
    @offset, @limit = api_offset_and_limit
    @member_count = scope.count
    @member_pages = Paginator.new @member_count, @limit, params['page']
    @offset ||= @member_pages.offset
    @members =  scope.order(:id).limit(@limit).offset(@offset).to_a

    respond_to do |format|
      format.html { head 406 }
      format.api
    end
  end

  def show
    respond_to do |format|
      format.html { head 406 }
      format.api
    end
  end

  def new
    @role = params[:role_id].to_i
    @member = Member.new
  end

  def create
    members = []
    @members_was = @project.members.count
    if params[:membership]
      user_ids = Array.wrap(params[:membership][:user_id] || params[:membership][:user_ids])
      user_ids << nil if user_ids.empty?
      user_ids.each do |user_id|
        member = Member.find_or_new(@project.id, user_id)
        all_ids = params[:membership][:role_ids] + member.role_ids
        member.set_editable_role_ids(all_ids)
        members << member
      end
      @project.members << members
    end

    respond_to do |format|
      format.html { redirect_to_settings_in_projects }
      format.js {
        @members = members
        @member = Member.new
      }
      format.api {
        @member = members.first
        if @member.valid?
          render :action => 'show', :status => :created, :location => membership_url(@member)
        else
          render_validation_errors(@member)
        end
      }
    end
  end

  def update
    @member_children = @member.children
    if params[:membership]
      @member.set_editable_role_ids(params[:membership][:role_ids])
    end
    saved = @member.save
    respond_to do |format|
      format.html { redirect_to_settings_in_projects }
      format.js
      format.api {
        if saved
          render_api_ok
        else
          render_validation_errors(@member)
        end
      }
    end
  end

  def destroy
    @member_children = @member.children

    if @member.deletable?
      @member.destroy
    else
      if @member.user.present?
        @un_inherited_roles = @member.member_roles.where(inherited_from:nil)
        if @un_inherited_roles.present? && @member.any_inherited_role?
          @un_inherited_roles.delete_all
        end
      end
    end
    respond_to do |format|
      format.html { redirect_to_settings_in_projects }
      format.js
      format.api {
        if @member.destroyed?
          render_api_ok
        else
          head :unprocessable_entity
        end
      }
    end
  end

  def autocomplete
    @role = params[:role_id].to_i
    respond_to do |format|
      format.js
    end
  end

  def fetch
    #@roles = Role.find_all_givable
    @role_ids = @project.current_roles
    @roles = Role.where(id: @role_ids)
    respond_to do |format|
      format.js
    end
  end

  # Users by role
  def users
    @role = params[:role_id]
    @members = @project.principals_of_role(params[:role_id])
    respond_to do |format|
      format.js
    end
  end

  def group_members
    @member_role = @member.member_roles.where(role_id: params[:role_id].to_i).last
    @members = @project.members.joins(:member_roles).where(member_roles: {inherited_from: @member_role.id}).includes(:principal)
    respond_to do |format|
      format.js
    end
  end

  def members
    @members = @project.memberships.active
                       .includes(:member_roles, :roles, :principal)
                       .joins(:member_roles)
                       .where(member_roles: {inherited_from: nil}).to_a.sort
  end

  def roles
    role_ids = @project.current_roles
    @roles = Role.where(id: role_ids)
  end

  private

  def redirect_to_settings_in_projects
    redirect_to settings_project_path(@project, :tab => 'members')
  end
end
