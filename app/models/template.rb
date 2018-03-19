class Template < ActiveRecord::Base
	belongs_to :role
  belongs_to :principal, :foreign_key => 'object_id'

  TEMPLATE_OBJECT_TYPE = {:user => 1, :group => 2}
  TEMPLATE_ROLE_TYPE = {:app_none => 1, :project_none => 2, :project_group => 3}.freeze

  validates :role_id, presence: true
  validates :object_id, presence: true, if: :group?


  scope :roles, -> { joins(:role).select("templates.id, roles.name") }
  scope :roles_by_object, -> { select("templates.id, roles.name, GROUP_CONCAT(users.lastname) as group_names")
                               .joins("INNER JOIN users ON templates.object_id = users.id AND users.type IN ('Group', 'GroupBuiltin', 'GroupAnonymous', 'GroupNonMember')
                                       INNER JOIN roles ON templates.role_id = roles.id")
                               .where("role_type = 3").group("object_id")}

  def group?
    role_type == 3
  end

  def valid_roles_and_groups
    if ([2, 3]).include?(role_type)
      temp_ids = Template.where(role_type: [2, 3]).pluck(:role_id)
      @roles = Role.where.not(id: temp_ids).sorted.pluck(:name, :id)
    else
    	temp_ids = Template.where(role_type: 1).pluck(:role_id)
    	@roles = Role.where.not(id: temp_ids).sorted.pluck(:name, :id)
    end

    @roles = new_record? ? @roles : @roles.unshift([role.name, role.id]) 

    group_ids = Template.where(role_type: 3).pluck(:object_id)
    @groups = role_type == 3 ? Group.where.not(id: group_ids).pluck(:lastname, :id) : []

    return @roles, @groups
  end
end
