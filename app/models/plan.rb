class Plan < ActiveRecord::Base
  belongs_to :project
  belongs_to :assigned_to, class_name: "User"
  belongs_to :check_user, class_name: "User"
  belongs_to :author, :class_name => 'User'

  acts_as_task :view_permission => :view_plans,
                     :edit_permission => :edit_plans,
                     :delete_permission => :edit_plans
  acts_as_recordable :view_permission => :edit_plans,
                     :edit_permission => :edit_plans,
                     :delete_permission => :edit_plans

  validates :name, :project_id, presence: true

  scope :sorted, lambda {order(:position)}
  # after_create :update_position

  # Yields the given block for each plan with its level in the tree
  def self.plan_tree(plans, &block)
    ancestors = []
    plans.sort_by(&:lft).each do |plan|
      while (ancestors.any? && !plan.is_descendant_of?(ancestors.last))
        ancestors.pop
      end
      yield plan, ancestors.size
      ancestors << plan
    end
  end

  # Returns the names of attributes that are altered when updating the plan
  def altered_attribute_names
    Plan.column_names - %w(id lft rgt created_on updated_on)
  end

  def init_alter_for(user, notes = "")
    @current_alter_for ||= AlterRecord.new(:alter_for => self, :user => user, :notes => notes)
  end

  # Returns the current journal or nil if it's not initialized
  def current_alter_for
    @current_alter_for
  end

  def generate_alter_records
    self.alter_records << current_alter_for
  end

  def children
    Plan.where("parent_id in (#{self.id})")
  end

  def parent
    Plan.find_by_parent_id self.parent_id
  end

  def locked
    project.plan_locked
  end

  private
  def update_position
    self.position = self.project.plans.reorder(:id).index_of(self) + 1
  end
end
