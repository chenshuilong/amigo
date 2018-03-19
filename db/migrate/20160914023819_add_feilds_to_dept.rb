class AddFeildsToDept < ActiveRecord::Migration
  def change
    add_column :depts, :createBy, :integer #创建人
    add_column :depts, :leve, :integer #等级，没有实际意义，SAP没有传等级过来 这个是我们自己原先设计的表的字段
    add_column :depts, :lastDate, :datetime #更新时间
    add_column :depts, :lastUpd, :integer #更新人
    add_column :depts, :otype, :string,:limit => 10 #类型：O：部门，P：人 S：表示职位
    add_column :depts, :staDate, :datetime #开始时间
    add_column :depts, :oveDate, :integer #结束时间
    add_column :depts, :status, :integer #状态：2有效，1无效
    add_column :depts, :remark, :text #备注信息
  end
end
