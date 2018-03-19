module PeriodicVersionsHelper
  include VersionsHelper

  def running_days_every_week(task)
    weekday = task.weekday
    return if weekday.blank?
    days_index = weekday.split(//).map(&:to_i).uniq
    if days_index.size == 7
      l(:version_periodic_task_everyday)
    else
      l('date.day_names').values_at(*days_index).join("、")
    end
  end

end
