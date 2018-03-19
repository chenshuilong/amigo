class GoogleToolPolicy < ApplicationPolicy
  def index?
    user.admin || auth
  end

  def category?
    user.admin || auth
  end

  def operate?
    user.admin || auth
  end

  def new?
    user.admin || auth
  end

  def create?
    user.admin || auth
  end

  def edit?
    user.admin || auth
  end

  def update?
    user.admin || auth
  end

  def destroy?
    user.admin || auth
  end
end
