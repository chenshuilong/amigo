class NativeApplistPolicy < ApplicationPolicy
  def index?
    can_view?
  end

  def show?
    can_view?
  end

  def edit?
    can_edit?
  end

  def new?
    can_edit?
  end

  def create?
    new?
  end

  def update?
    edit?
  end

  def destroy?
    can_edit?
  end

  def history?
    can_view?
  end

  private
  def can_edit?
    user.admin? || auth(:edit?)
  end

  def can_view?
    user.admin? || auth(:edit?) || auth(:view?)
  end
end
