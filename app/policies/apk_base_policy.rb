class ApkBasePolicy < ApplicationPolicy
  def index?
    user.admin || auth
  end
end
