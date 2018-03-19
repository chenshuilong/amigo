class IssueToSpecialTestsController < ApplicationController
  before_filter :require_login
  before_action :find_project
  before_action :find_special_test, only: [:edit, :update, :show]

  menu_item :issues

  def index
    scope = @project.special_tests.includes(:author)
    @limit = per_page_option
    @count = scope.count
    @pages = Paginator.new @count, @limit, params['page']
    @offset ||= @pages.offset
    @specials = scope.limit(@limit).offset(@offset).reorder("created_at desc").to_a
  end

  def new
    @special_test = IssueToSpecialTest.new(project_id: @project.id, status: 1)
  end

  def create
    @special_test = IssueToSpecialTest.new(special_params)
    @special_test.author_id = User.current.id
    @special_test.project_id = @project.id

    if @special_test.save
      respond_to do |format|
        format.html { redirect_to project_issue_to_special_tests_path(@project) }
        format.api { render :text => "Saved!", :status => :ok }
      end
    else
      respond_to do |format|
        format.html { render 'new' }
        format.api { render_error }
      end
    end
  end

  def edit
  end

  def update
    @special_test.update_attributes(special_params)
    if @special_test.save
      redirect_to project_issue_to_special_tests_path(@project)
    else
      render 'edit'
    end
  end

  def show
  end

  private

  def find_special_test
    @special_test = IssueToSpecialTest.find(params[:id])
  end

  def find_project
    @project = Project.find(params[:project_id])
  end

  def special_params
    special = params.require(:issue_to_special_test).permit(:subject, :category, :status, :test_times, :log_from_com, :machine_num, :test_method,
                                                            :attentions, :test_version, :related_issues, :priority, :approval_result, :precondition)
  end
end
