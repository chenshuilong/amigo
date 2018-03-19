class ProjectProgressPolicy < ApplicationPolicy
  def index?
    user.admin? || auth
  end
end
