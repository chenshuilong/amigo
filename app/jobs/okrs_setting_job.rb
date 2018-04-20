class OkrsSettingJob < ActiveJob::Base
  queue_as :default

  def perform(id)
    begin
      setting = OkrsSetting.find(id)
      all_users = Dept.find(2).all_users.where("users.status = 1").select("users.id").pluck(:id)
      admin_id = User.find_by(login: 'admin').id
      options = {}
      options[:admin_id] = admin_id
      Notification.transaction do
        puts "=====Start send notice to user start #{Time.now.strftime('%F %T')}====="
        Notification.send_user_submit_okrs_record(all_users, options)
        setting.update(last_running_at: Time.now)
        puts "=======End send notice to user at #{Time.now.strftime('%F %T')}========"
      end
    rescue => e
      logger.fatal('Error ocurred when send okrs record notice!')
      logger.fatal e
    end
  end
end
