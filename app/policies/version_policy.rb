class VersionPolicy < ApplicationPolicy
  def jenkins?
    user.admin? || auth(:jenkins?)
  end

  def compare?
    user.admin? || auth(:compare?)
  end

  def app_infos?
    user.admin? || auth
  end
end