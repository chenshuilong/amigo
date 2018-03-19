class CopyProjectMembersJob < ActiveJob::Base
  queue_as :copy_project_members

  def perform(project_id, user_id)
    @project = Project.find_by(id: project_id)
    @user    = User.find_by(id: user_id)

    begin
      @project.generate_members_by_template(@user)
    rescue => e
      logger.fatal "[FAILED] Copy #{@project.name}, error reason: #{e}"
    end
  end

  # def perform(from_project_id, to_project_id)
  #   begin
  #     from_project = Project.find(from_project_id)
  #
  #     if from_project.present?
  #       from_project.memberships.each do |from_member|
  #         if Project.find(to_project_id).members.find_by_user_id(from_member.user_id).blank?
  #           member = Member.find_or_new(to_project_id, from_member.user_id)
  #           from_member.member_roles.each do |from_member_role|
  #             member.member_roles << MemberRole.new(:role => from_member_role.role)
  #           end
  #           member.save!
  #         end
  #       end
  #     end
  #   rescue => e
  #     logger.fatal "[FAILED] Copy #{from_project.name} to #{Project.find(to_project_id).name}, error reason: #{e}"
  #   end
  # end
end
