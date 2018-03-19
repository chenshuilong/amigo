class DefinitionSectionsController < ApplicationController
  def index
    modules = DefinitionSection.all

    render :text => {:data => modules}.to_json
  rescue => e
    render :text => {:data => []}.to_json
  end

  def show
  end
end
