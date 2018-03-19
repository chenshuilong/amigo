class MokuaiOwnnersController < ApplicationController
  before_action :require_login

  def index
    @project = Project.find_by_identifier(params[:project_id])
    @projects = @project.same_mokuai_class_projects
    @mokuais = Mokuai.class_of(@project)
    @reasons = @mokuais.pluck(:reason).uniq
    @names = @mokuais.where(:reason => @reasons.first).order(:name)
    @users = @project.members
    @ownners = @project.mokuai_ownners
  end

  def create
    @project = Project.find_by_identifier(params[:project_id])
    ownner = @project.mokuai_ownners.new(mokuai_ownner_params)
    ownner.ownner = params[:ownner][:main_ownner].to_s.split | params[:ownner][:minor_ownner].to_a
    if ownner.save
      @ownners = @project.mokuai_ownners
      respond_to { |format| format.js }
    else
      if ownner.errors.messages.has_key?(:ownner)
        render :js => "alert('OWNER不能为空！')"
      else
        render :js => "alert('请勿重复添加！')"
      end
    end
  end

  def new
    @project = Project.find_by_identifier(params[:project_id])
    get = params[:get] || ""
    val = params[:val] || ""
    @names = ""
    if get == "reason"
      @names = params[:from].present?? Mokuai.class_of(@project).where(:reason => val).order(:name).pluck(:name, :id) :  @project.mokuais(val)
      val = @names.first.last rescue nil
    end

    if @mokuai_ownner = @project.mokuai_ownners.find_by(:mokuai_id => val)
      @ownner = User.find(@mokuai_ownner.ownner.try(:first)).to_json(:only => [:id, :firstname])
      @tfde = @mokuai_ownner.tfder.to_json(:only => [:id, :firstname])
    end
    @desc = Mokuai.find_by(:id => val).try(:description).to_s unless params[:from].present?
    respond_to { |format| format.js }
  end

  def edit
    @project = Project.find_by_identifier(params[:project_id])
    @users = @project.members
    @mokuai_ownner =  MokuaiOwnner.find_by_id(params[:id])
    respond_to { |format| format.js }
  end

  def destroy
    @mokuai_ownner_id = params[:id]
    MokuaiOwnner.find(@mokuai_ownner_id).destroy
    respond_to { |format| format.js }
  end

  def update
    @ownner = MokuaiOwnner.find(params[:id])
    ownner = params[:ownner][:main_ownner].to_s.split | params[:ownner][:minor_ownner].to_a
    tfde = params[:ownner][:tfde]
    @ownner.update_attributes(:ownner => ownner, :tfde => tfde)
    respond_to { |format| format.js }
  end

  def fetch
    @project = Project.find_by_id(params[:project][:id])
    @to = Project.find_by_id(params[:project][:to])
    to_users_array = @to.users.map{|u| u.id.to_s}
    @ownners = @project.mokuai_ownners.select{|o| (to_users_array & o.ownner).present? }
    respond_to { |format| format.js }
  end

  def copy
    @project = Project.find_by_identifier(params[:project_id])
    ids = params[:ids].reject{|id| id.blank?}
    MokuaiOwnner.copy_mokuai_ownner(@project, ids)
    @ownners = @project.mokuai_ownners
    respond_to { |format| format.js }
  end

  def reverse
    @project = Project.find_by_identifier(params[:project_id])
    @ownner = @project.mokuai_ownners.where("ownner like '%- \'?\'\n%'", params[:ownner])
    if @ownner.present?
      @reason, @name = @ownner.first.mokuai.reason, @ownner.first.mokuai.id
      @mokuais = Mokuai.class_of(@project).where(:reason => @reason).order(:name).pluck(:id, :name)
    end
    respond_to { |format| format.js }
  end

  private

  def mokuai_ownner_params
    params.require(:ownner).permit(:mokuai_id, :tfde)
  end

end
