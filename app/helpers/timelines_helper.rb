module TimelinesHelper
  def points(parent_id)
    @project.timelines.where(:parent_id => parent_id)
  end
end
