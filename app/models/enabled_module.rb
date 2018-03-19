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

class EnabledModule < ActiveRecord::Base
  belongs_to :project
  acts_as_watchable

  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :project_id
  attr_protected :id

  after_create :module_enabled

  private

  # after_create callback used to do things when a module is enabled
  def module_enabled
    case name
      when 'wiki'
        # Create a wiki with a default start page
        if project && project.wiki.nil?
          Wiki.create(:project => project, :start_page => 'Wiki')
        end
      when 'definitions'
        Definition.init(self.project_id) if project.definition.blank?
      when 'plans'
        # Create some initialize plans
        if project && project.plans.blank?
          # Create parent first
          template_plans.find_all { |plan| plan[:parent].nil? }.each { |parent|
            project.plans << Plan.new({:name => parent[:name]}) if project.plans.find_by_name(parent[:name]).blank?
          }
          # Create children later
          template_plans.find_all { |plan| plan[:parent].present? }.each { |p|
            project.plans << Plan.new({:name => p[:name], :parent_id => project.plans.find_by_name(p[:parent]).id}) if project.plans.find_by_name(p[:name]).blank?
          }
        end
    end
  end

  def template_plans
    project = Project.find_by_identifier("SW17G07A")
    plans = project.plans.where(:parent_id => nil).map { |plan| {:name => plan.name, :parent => nil} }
    project.plans.where(:parent_id => nil).each { |parent|
      project.plans.where(:parent_id => parent.id).each { |child|
        plans << {:name => child.name, :parent => parent.name}
      }
    }
    plans
  end
end
