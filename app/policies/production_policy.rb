class ProductionPolicy < ProjectPolicy
  def members?
    user.admin? || auth
  end

  def records?
    user.admin? || auth
  end

  def edit_info?
    user.admin? || auth
  end

  def update_info?
    edit_info?
  end
end
