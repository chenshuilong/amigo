class SpecPolicy < ApplicationPolicy
  def view_all?
    user.admin? || auth(:list?)
  end

  def view_own?
    !auth(:list?)
  end
end
