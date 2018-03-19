class Criterion < ActiveRecord::Base

  INDEXES = %[
    - name: 封板解决率
      identifier: fengBanJieJueLv
      purpose:
      description: |
        Bug解决率=Bug解决数/Bug有效数，
        有效Bug状态：三方分析+已修复+关闭+分配+打开+重分配+重打开+提交+申请裁决，
        解决Bug状态：已修复+关闭，
        提供所有严重度的问题解决率。
        从2017年4月份以后的项目，按此计算方法加上北研项目ROM的数据
      dept_range:
      output_time:
      settings:
      children:
      - name: S1必现解决率
        sort: s1BiXian
        target: 100%
      - name: S2必现解决率
        sort: s2BiXian
        target: 100%
      - name: S3必现解决率
        sort: s3BiXian
        target: 80%
      - name: S1随机解决率
        sort: s1SuiJi
        target: 90%
      - name: S2随机解决率
        sort: s2SuiJi
        target: 85%
      - name: S3随机解决率
        sort: s3SuiJi
        target: 80%
  ]

  serialize :settings, Hash
  has_many :children, -> {where('criterion_secondaries.active = 1')}, :class_name => 'CriterionSecondary', :foreign_key => 'parent_id'
  scope :active, -> {where(:active => true)}

  # update table data when app starting
  def self.update_indexes_info
    YAML::load(INDEXES).each do |index|
      criterion = find_by(:identifier => index['identifier'])
      if criterion
        exsit_sorts = criterion.children.pluck(:sort)
        index['children'].reject{|i| i['sort'].in?(exsit_sorts)}.each do |secondary|
          criterion.children.create secondary
        end
        children = criterion
      else
        criterion = create index.except('children')
        index['children'].each do |secondary|
          criterion.children.create secondary
        end
      end
    end
  end

  # update_indexes_info

  def settings
    self[:settings].with_indifferent_access
  end

  def settings=(content)
    self.settings.merge! content
  end

end
