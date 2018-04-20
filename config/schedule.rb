# Set whenever log file
set :output, "#{path}/log/whenever.log"
env :PATH, ENV['PATH']

every :day, :at => '02:00am' do
  rake "amigo:db_backup"
end

every :day, :at => '03:00am' do
  rake "amigo:attachment_merge_check"
end

every :day, :at => '05:00am' do # 1.minute 1.day 1.week 1.month 1.year is also supported
  rake "amigo:dept_sync"
  rake "amigo:user_sync"
  rake "amigo:clear_temp_file"
end

every :day, :at => '06:00am' do
  rake "amigo:group_sync"
  rake "amigo:resigned_notice"
  rake "amigo:undisposed_notice"
end

every 10.minutes do
  rake "amigo:periodic_task"
  rake "amigo:change_log_address"
  rake "amigo:upload_thirdparty_files"
  rake "amigo:okrs_submit_notice"
end

every 60.minutes do
  rake "amigo:refresh_user_redis"
end


# every 1.day, :at => '01:00am' do
#   rake "amigo:pick_issue_status_at_timestamp_once"
# end
#
# every :day, :at => '00:00am' do
#   rake "amigo:pick_issue_status_at_timestamp"
# end
