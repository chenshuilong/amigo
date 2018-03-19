class ViewRecordsController < ApplicationController
  def lists
    data = User.current.views.project_views.limit(15)
    render json: data.to_json
  end
end
