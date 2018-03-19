class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def scope
    Pundit.policy_scope!(user, record.class)
  end

  def self.auth(*definations)
    definations.each do |defination|
      name = /\?\z/ === defination ? defination : "#{defination.to_s}?"
      define_method name do; auth name end
    end
  end

  def auth(method = nil, obj = self)
    method = method || caller_locations(1,1)[0].label
    method = /\?\z/ === method ? method : "#{method.to_s}?"
    model  = obj.class.name.chomp("Policy").underscore
    action = "#{model}/#{method}"
    permissions = PolicyControl.read_action action
    (user.permissions & permissions.map(&:name)).present?
  end

  auth :index, :show, :create, :new, :update, :edit, :destroy

  # ---------------

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      scope
    end
  end
end
