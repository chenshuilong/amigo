class Qanda < ActiveRecord::Base

  scope :top, -> {order(total_read: :desc).limit(10)}

  validates :subject, :content, presence: true

  def next
    Qanda.where("id > ?", id).first
  end

  def prev
    Qanda.where("id < ?", id).last
  end

  def text(limit = nil)
    limit ||= -1
    Nokogiri::HTML(content).text.to(limit)
  end

  def add_view_count!
    update_column :total_read, self.total_read + 1
  end

end
