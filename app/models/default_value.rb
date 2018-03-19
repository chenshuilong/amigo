class DefaultValue < ActiveRecord::Base
  belongs_to :user

  scope :issue, -> {where(:category => "issue")}
  scope :version, -> {where(:category => "version")}

  validates :name, :category, :user_id, :json, presence: true


end
