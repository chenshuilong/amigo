# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

class DocumentsController < ApplicationController
  # default_search_scope :documents
  # model_object Document
  before_filter :find_project_by_project_id, :only => [:index, :new, :create, :new_version]
  # before_filter :find_model_object, :except => [:index, :new, :create, :new_version]
  # before_filter :find_project_from_association, :except => [:index, :new, :create, :new_version]
  before_action :require_login

  helper :attachments
  helper :custom_fields
  helper :sort
  include SortHelper

  def index
    @sort_by = %w(category date title author).include?(params[:sort_by]) ? params[:sort_by] : 'category'
    documents = @project.documents.includes(:attachments, :category).to_a
    case @sort_by
    when 'date'
      @grouped = documents.group_by {|d| d.updated_on.to_date }
    when 'title'
      @grouped = documents.group_by {|d| d.title.first.upcase}
    when 'author'
      @grouped = documents.select{|d| d.attachments.any?}.group_by {|d| d.attachments.last.author}
    else
      @grouped = documents.group_by(&:category)
    end
    @document = @project.documents.build

    @pages = (params['page'] || 1).to_i
    @limit = (params['per_page'] || 10).to_i

    @documents = @project.documents
    @documents = @project.documents.where(:title => params[:project_spec_version]) if params[:project_spec_version]
    if @documents
      @doc_count = @documents.count
      @doc_pages = Paginator.new @doc_count, @limit, @pages
      @documents = @documents.limit(@limit).offset(@limit*(@pages-1))
    end

    @document_category = DocumentCategory.for_production.all

    render :layout => false if request.xhr?
  end

  def show
    if params[:id]
      @document = Document.find(params[:id])
      @project = @document.project
    end
    @attachments = @document.attachments.to_a
  end

  def new
    @document = @project.documents.build
    @document.safe_attributes = params[:document]
  end

  def create
    @document = @project.documents.build
    @document.safe_attributes = params[:document]
    @document.save_attachments(params[:attachments])
    if @document.save
      render_attachment_warning_if_needed(@document)
      flash[:notice] = l(:notice_successful_create)
      redirect_to project_documents_path(@project)
    else
      render :action => 'new'
    end
  end

  def edit
    @document = Document.find(params[:id]) if params[:id]
    @project = @document.project
  end

  def update
    @document = Document.find(params[:id]) if params[:id]
    @document.safe_attributes = params[:document]
    if @document.save
      flash[:notice] = l(:notice_successful_update)
      redirect_to document_path(@document)
    else
      render :action => 'edit'
    end
  end

  def destroy
    @document = Document.find(params[:id]) if params[:id]
    @document.destroy if request.delete?
    @document.document_attachments.destroy
    if params[:id]
      render :text => {:success => 1, :message => "layer.alert('删除成功！');refreshPage();"}.to_json
    else
      redirect_to project_documents_path(@project)
    end
  end

  def add_attachment
    @document = Document.find(params[:id]) if params[:id]
    attachments = Attachment.attach_files(@document, params[:attachments])
    render_attachment_warning_if_needed(@document)

    if attachments.present? && attachments[:files].present? && Setting.notified_events.include?('document_added')
      Mailer.attachments_added(attachments[:files]).deliver
    end
    redirect_to document_path(@document)
  end

  def new_version
    @document_id = new_version_document_params[:id]

    if @document_id.to_i == 0
      @project.documents.create new_version_document_params if @project.documents.find_by_title(new_version_document_params[:title]).blank?
    else
      @document = Document.find new_version_document_params[:id]
      @document.update new_version_document_params if @document
    end

    respond_to do |format|
      format.api { render_api_ok }
    end
  end

  def upload
    @document = Document.find(upload_document_params[:id])

    if params[:attachments]
      atts = @document.save_attachments(params[:attachments])

      if @document.save
        atts[:files].each { |attachment|
          @document.document_attachments << DocumentAttachment.new({:category_id => upload_document_params[:category_id], :attachment_id => attachment.id})
        }
      end
    end
    render_attachment_warning_if_needed(@document)

    respond_to do |format|
      format.api { render_api_ok }
    end
  end

  private
  def new_version_document_params
    params.require(:document).permit(:id, :title, :description, :category_id)
  end

  def upload_document_params
    params.require(:document).permit(:id, :category_id)
  end
end
