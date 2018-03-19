class ApprovalsController < ApplicationController

  layout 'admin'
  before_filter :require_admin

  def index
    @approvals = Approval.all.to_a
  end

  def new
    @approval = Approval.new
  end

  def create
    @approval = Approval.new(approval_params)
    if @approval.save
      @approval.update_umpirage_approver
      redirect_to approvals_path
    else
      render "new"
    end
  end

  def edit
    @approval = Approval.find_by(:id => params[:id])
  end

  def update
    @approval = Approval.find_by(:id => params[:id])
    @approval.update_attributes(approval_params)
    if @approval.save
      redirect_to approvals_path
    else
      render "edit"
    end
  end

  def destroy
    Approval.find_by(:id => params[:id]).destroy
    redirect_to approvals_path
  end

  private

  def approval_params
    params.require(:approval).permit(:type, :object_type, :object_id, :user_id)
  end

end
