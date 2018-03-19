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

class RisksController < ApplicationController
  menu_item :risks

  before_filter :find_project_by_project_id
  before_filter :authorize

  helper :sort
  include SortHelper

  def index
    @risks =  Project.find(params[:project_id]).risks
  end

  def new
    @project = Project.find(params[:project_id])
    @risk = @project.risks.new
    1.times { @risk.risk_measures.build}
  end

  def create
    @project = Project.find(params[:project_id])
    @risk = @project.risks.new(risk_params)
    @risk.user = User.current unless @risk.user_id.present?
    if @risk.save
      redirect_to project_risks_path
    else
      1.times { @risk.risk_measures.build}
      render :new
    end
  end

  def update

  end

  private
  def risk_params
    params.require(:risk).permit(:department, :category, :description, :user_id, risk_measures_attributes: [:content, :finish_at])
  end


end
