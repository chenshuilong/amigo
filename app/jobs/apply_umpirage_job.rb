class ApplyUmpirageJob < ActiveJob::Base
  #queue_as :default
  queue_as :apply_umpirage

  def perform(args)
    issue = Issue.find(args.first)
    #user = User.find(args.last)
    user = issue.last_umpirage_approver
    project = issue.project

    # Add master to project's role group
    # master = User.find(1125) # Test
    #master = user.umpirage_approver
    
    current_masters, current_master_ids = user.find_umpirage_approver
    master = current_masters || [User.where(:admin => true, status: 1).third]

    current_master_ids.each do |m|
      member = project.members.find_by(:user_id => m) || Member.new(:project => project, :user_id => m)
      member.set_editable_role_ids(([Role.umpirage.id] | member.role_ids), User.find_by(admin: true))
      member.save
    end
 
    issue.update_columns(:umpirage_approver_id => current_master_ids) if current_master_ids.present?
    
    #Send email and notification

    ActionMailer::Base.raise_delivery_errors = true
    begin
      master.each do |m|
        Mailer.with_synched_deliveries do
          Mailer.apply_umpirage_notification(m, :user => user, :issue => issue).deliver
        end
      end
    rescue => e
      puts "[#{Time.now.to_s(:db)}] #{e.message}"
    end
    master.each do |m|
      Notification.apply_umpirage_notification(m, :user => user, :issue => issue)
    end
  end
end