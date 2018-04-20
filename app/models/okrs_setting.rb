class OkrsSetting < ActiveRecord::Base
  def send_notice
    current_time = Time.now
    if last_running_at.present?
      start_time = last_running_at
    else
      start_time = created_at
    end
    case cycle
    when "cycle"
      full_time = (start_time.to_date + interval.to_i.month).strftime("%F").split("-")
      year = full_time[0]
      month = full_time[1]
      setting_time = "#{year}-#{month}-#{date} #{time}".to_datetime - 8.hour
    when "none"
      setting_time = "#{date} #{time}".to_datetime - 8.hour
    end
    if setting_time <= current_time && start_time.to_date != current_time.to_date
      OkrsSettingJob.perform_now(self.id)
    end
  end
end
