class SignaturePolicy < ApplicationPolicy
  def index?
    user.admin? || auth
  end

  def show?
    user.admin? || auth
  end

  def new?
    user.admin? || auth
  end 

  def create?
    user.admin? || auth
  end
end