class RepoPolicy < ApplicationPolicy
  def index?
    user.admin? || auth
  end

  def show?
    user.admin? || auth
  end
  
  def compile_machine_status?
    user.admin? || auth
  end
end