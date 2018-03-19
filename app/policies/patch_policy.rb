class PatchPolicy < ApplicationPolicy
  def index?
    user.admin? || auth
  end

  def new?
    user.admin? || auth
  end

  def create?
    new?
  end

  def show?
    user.admin? || auth
  end
end