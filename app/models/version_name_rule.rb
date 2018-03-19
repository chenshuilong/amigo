class VersionNameRule < ActiveRecord::Base

  belongs_to :author, :class_name => 'User'

  validates :name, presence: true, uniqueness: true

  def self.permit?(user = User.current)
    user.admin? || user.groups.pluck(:lastname).include?('定期版本-项目版本号规则制定人')
  end

  def android_platform_frozen?
    !(self.new_record? || self.android_platform.blank?)
  end
end
