class CriterionsController < ApplicationController

  def index
    @criterions = Criterion.includes(:children)
  end

  def show
  end

  def edit
    @criterion = Criterion.find(params[:id])
    respond_to do |format|
      format.html
      format.js
    end
  end

  def update
    @criterion = Criterion.find(params[:id])
    @criterion.attributes = criterion_params
    @criterion.settings = params[:criterion][:settings]
    if @criterion.save
      params[:children].each do |key, value|
        @criterion.children.find(key).update_attributes(criterion_children_params(key))
      end
    end

    redirect_to :criterions
  end

  private

  def criterion_params
    params.require(:criterion).permit(:purpose, :dept_range, :output_time, :settings)
  end

  def criterion_children_params(key)
    params[:children].require(key).permit(:target)
  end


end
