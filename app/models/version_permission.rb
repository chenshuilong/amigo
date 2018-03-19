# -*- encoding : utf-8 -*-

class VersionPermission < ActiveRecord::Base
  has_many :alter_records, :as => :alter_for, :dependent => :destroy, :inverse_of => :alter_for

  validates :name, presence: true
  validates_uniqueness_of :name, conditions: -> { where(deleted: false) }
  
  after_save :create_alter

  def deleted!
    update(deleted: true, deleted_by_id: User.current.id)
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
    names = VersionPermission.column_names - %w(id created_at updated_at)
  end

  def self.drop_name_space
    @permissions = all 

    @permissions.each do |permission|
      permission.name = permission.name.gsub(/\s+/, "")
      permission.save
    end
  end
end
