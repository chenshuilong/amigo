class TopNoticesController < ApplicationController

  layout 'admin'
  before_filter :require_admin

  def index
    @top_notice = TopNotice.new
    @top_notices = TopNotice.all.order(:created_at => :desc)
  end

  def create
    top_notice = TopNotice.new(top_notice_params)
    top_notice.receivers = params[:top_notice][:receivers].reject(&:blank?).join(",") if top_notice.receiver_type != 1
    top_notice.user = User.current
    top_notice.uniq_key = SecureRandom.hex
    if top_notice.save
      flash.now[:notice] = l(:top_notices_create_success)
    else
      flash.now[:error] = l(:top_notices_create_failed)
    end
    @top_notice = TopNotice.new
    @top_notices = TopNotice.all.order(:created_at => :desc)
    render "index"
  end

  private

  def top_notice_params
    params.require(:top_notice).permit(:message, :receiver_type, :expired)
  end

end
