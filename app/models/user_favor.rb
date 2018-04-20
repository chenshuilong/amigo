class UserFavor < ActiveRecord::Base
  belongs_to :user

  before_create :set_favors_order
  after_create { |uf| uf.url = "http://" + self.url.to_s unless self.url.to_s.start_with?('http://') && self.url.to_s.start_with?('https://') }

  validates :title, presence: true, length: {maximum: 50}
  validates :url, presence: true
  validates_format_of :url, :with => URI::regexp(%w(http https))
  # validates_format_of :url, :with => /\A(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w\.-]*)*\/?\Z/i

  def url_valid?
    !!url.match(/^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-=\?]*)*\/?$/)
  end

  default_scope { order(sort: :asc, updated_at: :desc) }

  def rand_image_index
    Random.new.rand(20)
  end

  private

  def set_favors_order
    self.sort = User.current.favors.first.blank? ? 1 : User.current.favors.last.sort + 1
  end
end
