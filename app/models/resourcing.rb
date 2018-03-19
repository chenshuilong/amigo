class Resourcing < ActiveRecord::Base
  serialize :permissions, Array

  belongs_to :user
  after_save :clear_cache_about_resourcing

  private

  def clear_cache_about_resourcing
    $redis.hdel("global/users_permissions", self.user_id)
  end

  def self.setable_permissions
    PolicyControl.permissions
  end

  def self.replace_transitions(users, transitions)
    plus_transitions = []
    dash_transitions = []

    transitions.each do |name, value|
      case value
        when '1' then plus_transitions << name.to_sym
        when '0' then dash_transitions << name.to_sym
      end
    end

    return if plus_transitions.blank? && dash_transitions.blank?

    transaction do
      users.each do |user|
        resourcing = user.resourcing
        if resourcing.nil?
          Resourcing.create(:user_id => user.id, :permissions => plus_transitions)
        else
          permissions = (resourcing.permissions - dash_transitions) | plus_transitions
          resourcing.update_attribute(:permissions, permissions)
        end
      end
    end
  end

end
