class Dept < ActiveRecord::Base
  include Redmine::SafeAttributes

  # Dept statuses
  STATUS_ACTIVE     = 2
  STATUS_LOCKED     = 1

  scope :active, -> {where(:status => STATUS_ACTIVE)}
  scope :max_level, -> {select("max(leve) max_level").first.max_level}

  has_many :users, class_name: "User", foreign_key: "orgNo", :primary_key => "orgNo"

  #available main depts
  AVAIS ||=  [
      '50063356', # AMIGO开发院
      '50063363', # AMIGO产品运营院
      '50063374', # 大数据中心
      '50063384', # 知识产权部
      '10100054', # 智能软件研发院
      '50033233', # 终端产品中心
      '50063747', # 生产质量中心（海外）
      '50063745', # 硬件研发中心（海外）
      '50063746', # 软件及互联研发中心（海外）
      '20100023', # 金铭品质管理部
      '30200002', # 金卓品质管理部
      '50071013'  # 测试及质量管理部
  ]

  # Reasons' depts'
  AFFILIATION_DEPT ||= {
      "ROM" => [50034477, 50014374, 50034020, 50014361, 50014362,
                50014357, 50011896, 50034014, 50014352, 50033233],
      "测试" => [10100028],
      "驱动" => [50034013],
      "软件" => [50034009],
      "射频" => [10100079],
      "相机" => [10100080],
      "品质" => [20100023]
  }

  # Test role users' depts
  TEST_DEPT ||= [
      '10100028', # 深圳金立---终端产品中心---深圳研发院---测试部
      '10100044', # 深圳金立---终端产品中心---北京研发院---测试部
      '50027125', # 海外事业部---生产质量中心---测试及质量管理部
      '20100029', # 东莞金铭---品质管理部---品质管理部软件测试科
      '30200063', # 东莞金卓---品质管理部---品质管理部软件测试科
      '50063352', # 深圳金立---OS产品中心---智能软件研发院---测试部
      '50071013'  # 深圳金立---海外事业部---项目生产质量中心
  ]

  # User sync who are in these depts every day
  USER_SYNC_DEPT ||= [
      '10100081', # 产品规划中心
      '20100023', # 品质管理部
      '30200002', # 金卓品质管理部
      '88100000', # 海外事业部
      '50011894', # OS产品中心
      '50033233', # 终端产品中心
      '50061875', # 监察部
      '10100018'  # 信息中心

  ]

  # User group sync every day
  USER_GROUP_DEPT ||=[
      {
        :to_group_name => "项目-开发工程师",
        :from_dept_no => %w(50063309 50063345 50063346 50063349 50063356 50063363 50063374 10100024 10100026
                            10100027 10100031 50063387)
      },
      {
        :to_group_name => "项目-开发工程师(诚壹)",
        :from_dept_no => %w(50065993 88100006 50047156 50063748 50071731)
      },
      {
        :to_group_name => "项目-测试工程师",
        :from_dept_no => %w(10100028 50063352)
      },
      {
        :to_group_name => "项目-测试工程师(诚壹)",
        :from_dept_no => %w(50071066 50071731)
      },
      {
        :to_group_name => "项目-品质测试工程师",
        :from_dept_no => %w(20100023 30200002)
      },
      {
        :to_group_name => "项目-国内SPM",
        :from_dept_no => ['50064171']
      },
      {
        :to_group_name => "项目-SQA",
        :from_dept_no => ['50064172']
      }
  ]

  # Undisposed bugs notification every day
  NOTICE_UNDISPOSED_BUGS_DEPT ||= ['50011894'] # OS

  # SQA dept
  SQA_DEPT ||= '50064172'

  safe_attributes 'orgNm',
                  'orgNo',
                  'parentNo',
                  'created_at',
                  'updated_at',
                  'createBy',
                  'leve',
                  'lastDate',
                  'lastUpd',
                  'otype',
                  'staDate',
                  'oveDate',
                  'status',
                  'remark',
                  'manager_id',
                  'sub_manager_id',
                  'supervisor_id',
                  'majordomo_id',
                  'vice_president_id',
                  'comNm',
                  'parentNm',
                  'manager_number',
                  'manager_name',
                  'manager2_number',
                  'manager2_name',
                  'sub_manager_number',
                  'sub_manager_name',
                  'sub_manager2_number',
                  'sub_manager2_name',
                  'supervisor_number',
                  'supervisor_name',
                  'supervisor2_number',
                  'supervisor2_name',
                  'majordomo_number',
                  'majordomo_name',
                  'sub_majordomo_number',
                  'sub_majordomo_name',
                  'vice_president_number',
                  'vice_president_name',
                  'vice_president2_number',
                  'vice_president2_name'

  scope :users,lambda{|nos| select("users.*").joins("LEFT JOIN users ON depts.orgNo = users.orgNo").where("#{User.table_name}.orgNo in ('#{nos}')")}

  def self.options_group_for_select
    opts = []
    where(:orgNo => AVAIS).order("orgNo").each do |dept|
      opts << "<optgroup label=\"#{dept.orgNm}\" >"
      dept.children.each do |d|
        opts << "<option value=\"#{d.id}\">#{d.orgNm}</option>"
        d.children.each{|dd| opts << "<option value=\"#{dd.id}\"> >>#{dd.orgNm}</option>"} if d.children.present?
      end
      opts << "</optgroup>"
    end
    opts
  end

  def self.select2_available_depts(key = nil)
    key ||= :id
    ids = AVAIS

    Dept.where(:orgNo => ids).order("FIELD(orgNo, #{ids*','})").map do |dept|
      value = []
      dept.children.active.each do |d|
        value << {:text => d.orgNm.gsub(dept.orgNm, ""), :id => d.send(key)}
        d.children.active.each{|dd| value << {:text => "　» #{dd.orgNm.split("－").last}", :id => dd.send(key)}} if d.children.present?
      end
      prefix = "海外" if %w(50063747 50063745 50063746).include?(dept.orgNo)
      {:text => prefix.to_s + dept.orgNm, :children => value}
    end
  end

  def self.find(*args)
    if args.first && args.first.to_i >= 10_000_000
      dept = find_by_orgNo(*args)
      raise ActiveRecord::RecordNotFound, "Couldn't find Dept with orgNo=#{args.first}" if dept.nil?
      dept
    else
      super
    end
  end

  def self.build_dept_tree
    begin
      redis = Redis.new
      redis.set("amigo_dept_tree", Dept.first.query_all_down_depts.to_yaml)
    rescue => e
      logger.info("\nRedisError #{e}: (#{File.expand_path(__FILE__)})\n")
    end
  end

  def query_all_down_depts(id = nil)
    id ||= self.orgNo
    ids ||= [id.to_i]
    dept = Dept.find_by(:orgNo => id)
    depts = dept.children
    if depts.present?
      depts.each do |d|
        ids << query_all_down_depts(d.orgNo)
      end
    end
    ids
  end

  def parent
    Dept.find_by(:orgNo => self.parentNo)
  end

  def children
    Dept.where("parentNo in ('#{self.orgNo}')")
  end

  def all_users
    ids = all_down_depts(self.orgNo)
    User.where(:orgNo => ids)
  end

  def all_down_depts(id = nil)
    id ||= self.orgNo
    begin
      redis = Redis.new
      depts_yml = redis.get("amigo_dept_tree")
      depts = YAML.load(depts_yml).to_s

      start_index = depts.index("[#{id.to_i}")
      end_index = flag = -1

      for i in (start_index + 1..depts.size) do
        flag += {'[' => -1, ']' => 1}.fetch(depts[i]) {0}
        if flag.zero? then end_index = i; break end
      end

      depts[start_index..end_index].scan(/\d+/)
    rescue
      Dept.build_dept_tree
      query_all_down_depts(id).flatten
    end
  end


  def all_up_levels(option = {})
    get_id = option[:id]? "id" : "orgNo"
    ids = []
    @dept = self
    loop do
      ids << @dept.send(get_id.to_sym)
      @dept = @dept.parent
      break if @dept.blank?
    end
    ids
  end

  # def all_down_levels
  #   ids = []
  #   @dept = self
  #   loop do
  #     ids << @dept.orgNo
  #     @dept = @dept.children
  #     break if @dept.blank?
  #   end
  #   ids
  # end


  def all_smallest_depts(dept = nil)
    Dept.active.where(orgNo: all_down_depts).to_a.reject{ |d| d.children.present? }
  end

  alias_method :all_down_levels, :all_down_depts
  alias_method :all_up_depts, :all_up_levels

  def method_missing(name, *args)
    if attributes.keys.include?("#{name}_number")
      emp_id = send("#{name}_number")
      emp_id = 'cenx' if emp_id.blank?
      User.find_by(:empId => emp_id)
    else
      super
    end
  end

  def name
    orgNm
  end

end
