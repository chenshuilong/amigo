class Mokuai < ActiveRecord::Base

  has_many :issues, :class_name => 'Issue', :foreign_key => 'mokuai_name'
  has_many :alter_records, :as => :alter_for, :dependent => :destroy, :inverse_of => :alter_for

  after_save :clear_cache_about_mokuai
  after_save :create_alter

  validates :category, :reason, :name, presence: true
  validates :name, :uniqueness => {scope: [:category, :reason], :message => :mokuai_name_already_exists}

  MOKUAI_CATEGORY = {"终端" => 1, "运营商" => 2, "Server" => 3, "Autotest" => 4, "海外" => "5"}
  MOKUAI_CATEGORY_DEFAULT = 1
  MOKUAI_CATEGORY_XIANXIANG = 100

  scope :xianxiang, -> {cate(MOKUAI_CATEGORY_XIANXIANG)}

  class << self

    def cate(fix)
      return [] if fix.blank?
      where(:category => fix)
    end

    def default
      cate(MOKUAI_CATEGORY_DEFAULT)
    end


    def class_of(project)
      project.mokuai_class.present? ? cate(project.mokuai_class) : default
    end

    def import(file)
      spreadsheet = Import.open(file)
      header = spreadsheet.row(1)
      # return spreadsheet.cell("A", 2).class
      (2..spreadsheet.last_row).each do |i|
        row = Hash[[header, spreadsheet.row(i)].transpose]
        mokuai = new(row)
        # mokuai.attributes = row.to_hash.slice(*updatable_attributes)
        mokuai.save!
      end
    end

    def find_by_auto_submit(from_name)
      method = "#{from_name.to_s}_mokuai"
      if respond_to? method
        send method
      else
        new
      end
    end

    def insight_mokuai
      find_by(:id => 1119)
    end

    def auto_test_mokuai
      find_by(:id => 11)
    end

  end

  def is_xx?
    category == MOKUAI_CATEGORY_XIANXIANG
  end

  def xx_priority
    IssuePriority.find_by(:id => description.to_i).try(:name) if description.present?
  end

  def desc
    is_xx?? xx_priority : description
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
    names = Mokuai.column_names - %w(id created_at updated_at package_name default_tfde)
  end

  def generate_alter_record
    @record = AlterRecord.new(alter_for_id: self.id, alter_for_type: self.class.name, notes: "add")
    notes = "[新增] 归属: #{reason}, 模块: #{name}"
    notes = notes + ", 包名: #{package_name} " if package_name.present?
    notes = notes + ", 描述: #{description}" if description.present?
    @record.details.build(property: 'new', value: notes)
    @record.save
  end

  private

  def clear_cache_about_mokuai
    $redis.del "issues/index.mokuais"
  end


end
