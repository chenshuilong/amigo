class ViewRecord < ActiveRecord::Base
  belongs_to :container, :polymorphic => true
  belongs_to :user

  validates_uniqueness_of :container_id, :scope => [:container_type, :user_id]

  scope :project_views, lambda { select("projects.name, projects.identifier")
  	                             .joins('INNER JOIN projects ON projects.id = container_id AND container_type = "Project"')
  	                             .reorder("updated_at desc") }
end
