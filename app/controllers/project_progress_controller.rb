
class ProjectProgressController < ApplicationController

  def index
    auth :project_progress

    @progress = Project.progress
  end
end
