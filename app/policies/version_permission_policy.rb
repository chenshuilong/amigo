class VersionPermissionPolicy < ApplicationPolicy
  def index?
     can_view?
  end

  def change?
     can_edit?
  end

  def destroy?
    can_edit?
  end

  private
  def can_edit?
     user.admin? || auth(:edit?)
  end

  def can_view?
    user.admin? || auth(:edit?) || auth(:view?)
  end
end