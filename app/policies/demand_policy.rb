class DemandPolicy < ApplicationPolicy
  def index?
    auth
  end

  def show?
    index?
  end

  def new?
    auth
  end

  def create?
    new?
  end

  def edit?
    user.id == record.author_id && !record.closed?
  end

  def update?
    edit?
  end
end
