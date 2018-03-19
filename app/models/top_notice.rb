class TopNotice < ActiveRecord::Base

  belongs_to :user

  RECEIVER_TYPE = {"1" => "所有人", "2" => "指定人", "3" => "指定部门"}

  scope :top, -> {order(created_at: :desc).try(:first)}

  validates :message, :receiver_type, :expired, :uniq_key, presence: true
  validates :receivers, presence: true, unless: -> { receiver_type == 1 }

  def invalid?
    !User.current.logged? || self.blank? || expired < Date.today
  end

  def receivers_content
    case receiver_type
      when 1
        "-"
      when 2
        User.where(:id => receivers.split(",")).pluck(:firstname).join("/")
      when 3
        Dept.where(:id => receivers.split(",")).pluck(:orgNm).join("/")
    end
  end

  private


end
