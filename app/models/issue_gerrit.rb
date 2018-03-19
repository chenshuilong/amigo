class IssueGerrit < ActiveRecord::Base
  belongs_to :issue
  belongs_to :user

  validates :issue_id, :user_id, :message, :link, :repository, :branch, presence: true

  def is_git?
    /^(https|http|ftp|rtsp|mms)/ === link
  end

  def message_without_change_id
    message.gsub(/Change\-Id[^$]+/, '')
  end

end

