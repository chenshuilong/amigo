class IssueToSpecialTestResultsController < ApplicationController
  before_filter :require_login
  before_action :find_special_test, only: [:new, :create]
  before_action :find_project
  before_action :find_result, only: [:show, :update]

  helper :attachments
  helper :issue_to_special_tests
  helper :tasks
  menu_item :issues

  def index
    scope = IssueToSpecialTestResult.joins(:special_test).where(issue_to_special_tests: {project_id: @project}).includes(:designer, :assigner)
    @limit = per_page_option
    @count = scope.count
    @pages = Paginator.new @count, @limit, params['page']
    @offset ||= @pages.offset
    @results = scope.limit(@limit).offset(@offset).reorder("issue_to_special_test_results.created_at desc").to_a
  end

  def new
    @result = IssueToSpecialTestResult.new(special_test_id: @special_test.id)
  end

  def create
    @result = IssueToSpecialTestResult.new(result_params)
    @result.special_test_id = @special_test.id
    if @result.save
      Task.create!({:container_id => @result.id,
                    :container_type => "IssueToSpecialTestResult",
                    :name => "专项测试_"+@special_test.subject,
                    :assigned_to_id => @result.designer_id,
                    :start_date => Time.now.to_s(:db),
                    :author_id => User.current.id,
                    :status => 9}) if @result.task.blank?

      respond_to do |format|
        format.html { redirect_to project_issue_to_special_test_results_path(@project) }
        format.api { render :text => "Saved!", :status => :ok }
      end
    else
      respond_to do |format|
        format.html { render 'new' }
        format.api { render_error }
      end
    end
  end

  def show
    @special_test = @result.special_test
    @task = @result.task
    @records = AlterRecord.joins(:details).where(alter_for_id: @result.id,  alter_for_type: 'IssueToSpecialTestResult',alter_record_details: {prop_key: 'supplement'})
  end

  def update
    if params[:supplement].present?
      @alter_record = AlterRecord.create(alter_for_id: @result.id, alter_for_type: @result.class.name, user_id: User.current.id, notes: params[:supplement])
      @alter_record.details.create(prop_key: "supplement", value: params[:supplement])
    end
    @result.save_attachments(params[:attachments])
    if @result.save
      respond_to do |format|
        format.html { redirect_to :back }
        format.api { render :text => "Saved!", :status => :ok }
      end
    else
      respond_to do |format|
        format.html { render 'show' }
        format.api { render_error }
      end
    end
  end

  private

  def result_params
    params.require(:issue_to_special_test_result).permit(:special_test_id, :designer_id, :assigned_to_id, :steps, :sample_num, :catch_log_way,
                                                         :result, :notes)
  end

  def task_params
    params.require(:task).permit(:status)
  end

  def find_result
    @result = IssueToSpecialTestResult.find(params[:id])
  end

  def find_project
    @project = Project.find(params[:project_id])
  end

  def find_special_test
    @special_test = IssueToSpecialTest.find(params[:special_test_id])
  end
end
