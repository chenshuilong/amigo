class NotificationsController < ApplicationController
  before_filter :require_login

  include NotificationsHelper

  def index
    @tab = selected_tab
    @pages = (params['page'] || 1).to_i
    @limit = (params['per_page'] || 10).to_i
    @notice_count = Notification.cate(@tab[:name]).mine.count
    @notice_pages = Paginator.new @notice_count, @limit, @pages
    @notices = Notification.mine.cate(@tab[:name]).limit(@limit).offset(@limit*(@pages-1))
  end

  def handle
    @notification = Notification.find_by(:id => params[:id])
    category = @notification.category == "mission" ? 4 : (@notification.category == "condition" ? 1 : 3)
    @notification.update_depend_on(params[:do],category)
    respond_to do |format|
      format.js {render "notifications/ajax/#{@notification.category}.js"}
    end
  end
end
