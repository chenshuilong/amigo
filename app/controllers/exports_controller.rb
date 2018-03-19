class ExportsController < ApplicationController
  model_object Export
  before_action :find_model_object, :except => :index
  before_action :check_user_legal, :only => [:download, :destroy]

  def index
    user_exports = Export.mine.undeleted.order(created_at: :desc).map do |export|
      {
        :id => export.id,
        :name => export.name,
        :status => export.status,
        :status_text => l("export_status_#{Export.consts[:status].invert[export.status]}"),
        :format => export.format,
        :file_size => export.file_size.to_i.try(:to_s, :human_size),
        :before_it => (export.status == Export.consts[:status][:queued]) ? export.queued_before_self : nil
      }
    end
    render :json => user_exports
  end

  def download
    file_path = @export.file_path
    if File.exist? file_path
      send_file file_path, :filename => @export.download_file_name, :type => "application/octet-stream"
    else
      render_404
    end
  end

  def destroy
    render_api_ok if @export.do_delete!
  end

  private

  def check_user_legal
    render_403 if @export.nil? || @export.user_id != User.current.id
  end

end
