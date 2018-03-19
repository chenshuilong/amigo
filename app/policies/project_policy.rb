class ProjectPolicy < ApplicationPolicy

  def view_all?
    user.admin? || auth(:index?)
  end

  def view_owner?
    !view_all?
  end

  def show?
    user.admin? || auth || record.members.pluck(:user_id).include?(user.id)
  end

end
