class PeriodicVersionPolicy < ApplicationPolicy
  def index?
    user.admin? || auth
  end

  def show?
    user.admin? || auth
  end

  def version_name_rules?
    user.admin? || auth
  end
end