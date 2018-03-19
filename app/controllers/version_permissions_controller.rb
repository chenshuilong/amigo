class VersionPermissionsController < ApplicationController
  model_object VersionPermission
  
  before_filter :require_login
  before_action :find_model_object, :only => [:destroy]
  before_action :find_all_version_permissions, :except => [:add]
  #before_action :authorize_global

  def index
    auth :version_permission
    @remove_note = VersionPermission.where(name: "remove_notes")
  end

  def change
    auth :version_permission
    @version_permission = params[:id].present? ? find_model_object : VersionPermission.new
    render "change"
  end

  def save_change
    if params[:id].present?
      find_model_object
      @version_permission.init_alter
      result = @version_permission.update(meaning: version_permission_params[:meaning])
    else
      @version_permission = VersionPermission.new(version_permission_params)
      result = @version_permission.save
    end
    render json: result.to_json
  end

  def destroy
    auth :version_permission
    @version_permission.init_alter
    @version_permission.deleted!
    render json: true.to_json
  end

  private
  def version_permission_params
    permission_params = params.require(:version_permission).permit(:name, :meaning, :author_id)
    permission_params[:name] = permission_params[:name].gsub(/\s+/, "") if permission_params[:name].present?
    return permission_params
  end
  
  def find_all_version_permissions
    @version_permissions = VersionPermission.where.not(name: "remove_notes", deleted: true)
  end
end
