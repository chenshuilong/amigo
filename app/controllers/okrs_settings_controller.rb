class OkrsSettingsController < ApplicationController
  before_filter :require_login

  layout 'repo'

  def new
    if (setting = OkrsSetting.last).present?
      redirect_back_or_default edit_okrs_setting_path(setting)
    end
    @setting = OkrsSetting.new
    @setting.cycle = "cycle"
    
    if params[:format].present? && params[:format] == "js"
      @setting.cycle = okrs_settings_params[:interval].to_i == 0 ? "none" : okrs_settings_params[:cycle]
      @setting.interval = okrs_settings_params[:interval]
      @setting.date = @setting.cycle == "none" ? nil : okrs_settings_params[:date]
      render 'change'
    end
  end

  def create
    @setting = OkrsSetting.new(okrs_settings_params)
    @setting.author_id = User.current.id
    @setting.interval_type = "month"
    @setting.time = "10:00"

    respond_to do |format|
      if @setting.save
        format.html do
          flash[:notice] = l(:notice_successful_create)
          redirect_back_or_default edit_okrs_setting_path(@setting)
        end
      else
        format.html { render :action => 'new' }
      end
    end
  end

  def edit
    @setting = OkrsSetting.find(params[:id])
    if params[:format].present? && params[:format] == "js"
      last_cycle = @setting.cycle
      @setting.cycle = okrs_settings_params[:interval].to_i == 0 ? "none" : "cycle"
      @setting.interval = okrs_settings_params[:interval]
      @setting.date = last_cycle == @setting.cycle ? @setting.date : nil
      render 'change'
    end
  end

  def update
    @setting = OkrsSetting.find(params[:id])
    @setting.assign_attributes(okrs_settings_params)
    respond_to do |format|
      if @setting.save
        format.html do
          flash[:notice] = l(:notice_successful_update)
          redirect_back_or_default edit_okrs_setting_path(@setting)
        end
      else
        format.html { render :action => 'edit' }
      end
    end    
  end

  private
  def okrs_settings_params
    params.require(:okrs_settings).permit(:cycle, :interval, :interval_type, :date)
  end
end
