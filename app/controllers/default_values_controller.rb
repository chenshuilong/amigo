class DefaultValuesController < ApplicationController

  before_action :default_check_user, :only => [:load, :update, :destroy]

  def create
    @default_value = User.current.default_values.new(default_value_params)
    cate = @default_value.category.to_sym
    if @default_value.save
      @default_values = User.current.default_values.send cate
      respond_to do |format|
        format.js
      end
    end
  end


  def load
    @default_value = DefaultValue.find(params[:id])
    respond_to do |format|
      format.html {
        render :text => "Hello :)"
      }
      format.js { render "default_values/category/#{@default_value.category}.js.haml" }
    end
  end

  def update
    @default_value = DefaultValue.find(params[:id])
    @default_value.attributes = default_value_params
    # @default_value.json = params[:default_value][:json]
    render_api_head :ok if @default_value.save
  end

  def destroy
    @default_value = DefaultValue.find(params[:id])
    cate = @default_value.category.to_sym
    if @default_value.destroy
      @default_values = User.current.default_values.send cate
    end
    respond_to do |format|
      format.js
    end
  end

  private

  def default_value_params
    params.require(:default_value).permit(:category, :name, :json)
  end

  def default_check_user
    default_value = DefaultValue.find_by(:id => params[:id])
    if default_value.nil? || default_value.user != User.current
      head :forbidden
    else
      return true
    end
  end

end
