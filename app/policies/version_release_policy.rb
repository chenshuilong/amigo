class VersionReleasePolicy < ApplicationPolicy
  def index?
    user.admin? || auth
  end
end
