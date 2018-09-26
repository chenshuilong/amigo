class FlowFilePolicy < ApplicationPolicy
  def index?
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

  def manage?
    user.admin || auth
  end

  def show?
    user.admin || auth
  end
end
