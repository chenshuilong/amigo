class MyPolicy < ApplicationStructPolicy.new(:user, :my)

  def staffs?
    user.admin || auth
  end

  def links?
    user.admin || auth
  end

  def export?
    user.admin || auth
  end

end
