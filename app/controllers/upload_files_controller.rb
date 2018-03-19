class UploadFilesController < ApplicationController
	model_object Attachment
	before_filter :find_attachment, :only => [:show, :download, :destroy]
	
  def show
    respond_to do |format|
      format.html {
        if @attachment.is_diff?
          @diff = File.read(@attachment.diskfile, :mode => "rb")
          @diff_type = params[:type] || User.current.pref[:diff_type] || 'inline'
          @diff_type = 'inline' unless %w(inline sbs).include?(@diff_type)
          # Save diff type as user preference
          if User.current.logged? && @diff_type != User.current.pref[:diff_type]
            User.current.pref[:diff_type] = @diff_type
            User.current.preference.save
          end
          render :action => 'diff'
        elsif @attachment.is_text? && @attachment.filesize <= Setting.file_max_size_displayed.to_i.kilobyte
          @content = File.read(@attachment.diskfile, :mode => "rb")
          render :action => 'file'
        elsif @attachment.is_image?
          render :action => 'image'
        else
          render :action => 'other'
        end
      }
      format.api
    end
  end

  def download
    if @attachment.container.is_a?(Version) || @attachment.container.is_a?(Project)
      @attachment.increment_download
    end

    if stale?(:etag => @attachment.digest)
      # images are sent inline
      if !@attachment.remote_file?
        send_file @attachment.diskfile, :filename => filename_for_content_disposition(@attachment.filename),
                                        :type => detect_content_type(@attachment),
                                        :disposition => disposition(@attachment)
      else
        if @attachment.ftp_ip.present?
          redirect_to @attachment.ftp_file_url
          return
        else
          render :partial => "attachments/merging"
        end
      end
    end
  end

  def destroy
    if @attachment.container.respond_to?(:init_journal)
      @attachment.container.init_journal(User.current)
    end
    if @attachment.container
      # Make sure association callbacks are called
      @attachment.container.attachments.delete(@attachment)
    else
      @attachment.destroy
    end

    respond_to do |format|
      format.html { redirect_to_referer_or :back }
      format.js
      format.api { render_api_ok }
    end
  end

  private

  def find_attachment
    @attachment = Attachment.find(params[:id])
    # Show 404 if the filename in the url is wrong
    raise ActiveRecord::RecordNotFound if params[:filename] && params[:filename] != @attachment.filename
    @project = @attachment.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def detect_content_type(attachment)
    content_type = attachment.content_type
    if content_type.blank? || content_type == "application/octet-stream"
      content_type = Redmine::MimeType.of(attachment.filename)
    end
    content_type.to_s
  end

  def disposition(attachment)
    if attachment.is_image? || attachment.is_pdf?
      'inline'
    else
      'attachment'
    end
  end
end
