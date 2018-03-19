class VersionPublishPolicy < ApplicationPolicy
  def index?
    can_view?
  end

  def preview?
    can_view?
  end

  def edit?
    can_edit?
  end

  def history?
    can_view?
  end

  def publish?
    can_edit?
  end

  def show?
    can_view?
  end

  def export?
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
