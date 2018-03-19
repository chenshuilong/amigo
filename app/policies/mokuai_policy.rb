class MokuaiPolicy < ApplicationPolicy
  def list?
    user.admin? || auth
  end

  def history?
    list?
  end

  def edit_batch?
    list?
  end

  def sync_batch?
    list?
  end
end