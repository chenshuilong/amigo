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

class IssueCustomField < CustomField
  has_and_belongs_to_many :projects, :join_table => "#{table_name_prefix}custom_fields_projects#{table_name_suffix}", :foreign_key => "custom_field_id"
  has_and_belongs_to_many :trackers, :join_table => "#{table_name_prefix}custom_fields_trackers#{table_name_suffix}", :foreign_key => "custom_field_id"
  has_many :issues, :through => :issue_custom_values

  def self.xianxiang
    find_by(:name => '现象类型')
  end

  def self.pinzhi
    find_by(:name => '品质分类')
  end

  def data_json(issue)
    custom_field_values = issue.custom_field_values
    xx_value = custom_field_values.detect{|cv| cv.custom_field == self.class.xianxiang}.try(:value)
    case self
      when self.class.xianxiang
        Mokuai.xianxiang.pluck(:reason).push(xx_value).uniq
      when self.class.pinzhi
        xx = xx_value || Mokuai.xianxiang.first.try(:reason)
        pz_value = custom_field_values.detect{|cv| cv.custom_field == self.class.pinzhi}.try(:value)
        Mokuai.xianxiang.where(:reason => xx).pluck(:name).push(pz_value).uniq
    end
  end

  def type_name
    :label_issue_plural
  end

  def visible_by?(project, user=User.current)
    super || (roles & user.roles_for_project(project)).present?
  end

  def visibility_by_project_condition(project_key=nil, user=User.current, id_column=nil)
    sql = super
    id_column ||= id
    tracker_condition = "#{Issue.table_name}.tracker_id IN (SELECT tracker_id FROM #{table_name_prefix}custom_fields_trackers#{table_name_suffix} WHERE custom_field_id = #{id_column})"
    project_condition = "EXISTS (SELECT 1 FROM #{CustomField.table_name} ifa WHERE ifa.is_for_all = #{self.class.connection.quoted_true} AND ifa.id = #{id_column})" +
      " OR #{Issue.table_name}.project_id IN (SELECT project_id FROM #{table_name_prefix}custom_fields_projects#{table_name_suffix} WHERE custom_field_id = #{id_column})"

    "((#{sql}) AND (#{tracker_condition}) AND (#{project_condition}))"
  end

  def validate_custom_field
    super
    errors.add(:base, l(:label_role_plural) + ' ' + l('activerecord.errors.messages.blank')) unless visible? || roles.present?
  end
end
