class ReportPolicy < ApplicationPolicy
  def index?
    user.admin? || auth
  end

  def more?
    index?
  end
end
