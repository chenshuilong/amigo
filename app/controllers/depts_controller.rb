class DeptsController < ApplicationController

  def index
    respond_to do |format|
      @limit = per_page_option
      page = params[:page] || 1
      offset = (page.to_i - 1) * @limit

      format.html {
        render_api_ok
      }
      format.json {
        scope = $db.slave { Dept.active.select('id,orgNm') }
        scope = $db.slave { scope.where("orgNm like '%#{params[:name]}%'") } unless params[:name].to_s.strip.empty?

        @depts = $db.slave { scope.uniq.limit(@limit).offset(offset).to_a }
        render :json => @depts, :status => :ok
      }
    end
  end
end
