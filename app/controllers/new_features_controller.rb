class NewFeaturesController < ApplicationController

  before_filter :require_login
  before_action :require_admin, :except => :index

  def index
    # search = params[:q]
    # if search.present?
    #   scope = NewFeature.where("subject like ?", "%#{search}%")
    # else
    #   scope = NewFeature.all
    # end
    # @pages = (params['page'] || 1).to_i
    # @limit = (params['per_page'] || 25).to_i
    # @new_feature_count = scope.count
    # @new_feature_pages = Paginator.new @new_feature_count, @limit, @pages
    # @new_features = scope.limit(@limit).offset(@limit*(@pages-1))
    @new_features = NewFeature.all
    @grouped_new_features = @new_features.to_a.group_by{|f| f.created_at.to_date}
  end

  def new
    @new_feature = NewFeature.new
    respond_to { |format| format.js }
  end

  def create
    @new_feature = NewFeature.new(new_feature_params)
    if @new_feature.save
      redirect_to new_features_path
    end
  end

  def destroy
    NewFeature.find(params[:id]).destroy
    redirect_to new_features_path
  end

  private

  def new_feature_params
    params.require(:new_feature).permit(:category, :description)
  end

end
