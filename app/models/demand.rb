class Demand < ActiveRecord::Base
  include AASM

  has_many :alter_records, :as => :alter_for, :dependent => :destroy, :inverse_of => :alter_for
  belongs_to :author, :class_name => "User", foreign_key: "author_id"
  belongs_to :demand_category, :class_name => "DemandCategory", foreign_key: "category_id"
  belongs_to :source_category, :class_name => "DemandSourceCategory", foreign_key: "sub_category_id"

  validates :category_id, :sub_category_id, :description, :method, :feedback_at, presence: true

  after_save :create_alter

  acts_as_attachable :view_permission => :view_files,
                     :edit_permission => :manage_files,
                     :delete_permission => :manage_files

  DEMAND_STATUS = {
    :tracked => 1,
    :pending => 2,
    :closed => 3
  }

  enum status: DEMAND_STATUS

  # Define Workflow
  aasm :column => :status, :enum => true, :logger => Rails.logger do
    state :tracked, :initial => true
    state :pending, :closed
  end

  def init_alter(notes = "")
    @current_alter ||= AlterRecord.new(:alter_for => self, :user => User.current)
  end

  # Returns the current journal or nil if it's not initialized
  def current_alter
    @current_alter
  end

  def create_alter
    if current_alter
      current_alter.save
    end
  end

  def altered_attribute_names
    names = Demand.column_names - %w(id created_at updated_at)
  end
  
  def generate_notes_alter_record(notes)
    @alter_record = AlterRecord.create(alter_for_id: self.id, alter_for_type: self.class.name, user_id: User.current.id, notes: notes)
    @alter_record.details.create(prop_key: "notes", value: notes)
  end

  def visible_alter_records(prop_key = nil)
    if prop_key.present?
      self.alter_records.includes(:details).where(alter_record_details: {prop_key: prop_key})
    else
      self.alter_records.includes(:details).where.not(alter_record_details: {prop_key: "notes"})
    end
  end
end
