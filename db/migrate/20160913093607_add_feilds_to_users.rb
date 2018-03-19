class AddFeildsToUsers < ActiveRecord::Migration
  def change
    add_column :users, :birthday, :datetime #生日
    add_column :users, :deptSysNm, :string, :limit => 50 #系统
    add_column :users, :sub_system, :string, :limit => 50 #子系统
    add_column :users, :empId, :string, :limit => 20 #员工编号
    add_column :users, :group_bmjl_empId, :string, :limit => 20 #部门经理员工编号
    add_column :users, :group_bmjl_id, :string, :limit => 20 #部门经理ID
    add_column :users, :group_bmjl_name, :string, :limit => 15 #部门经理姓名
    add_column :users, :group_fujingli_empId, :string, :limit => 20 #副经理员工编号
    add_column :users, :group_fujingli_name, :string, :limit => 15 #副经理姓名
    add_column :users, :group_zgfz_empId, :string, :limit => 20 #主管副总员工编号
    add_column :users, :group_zgfz_id, :string, :limit => 20 #主管副总ID
    add_column :users, :group_zgfz_name, :string, :limit => 15 #主管副总姓名
    add_column :users, :group_zhuguan_empId, :string, :limit => 20 #主管员工编号
    add_column :users, :group_zhuguan_id, :string, :limit => 20 #主管ID
    add_column :users, :group_zhuguan_name, :string, :limit => 15 #主管姓名
    add_column :users, :group_zongjian_empId, :string, :limit => 20 #总监员工编号
    add_column :users, :group_zongjian_id, :string, :limit => 20 #总监ID
    add_column :users, :group_zongjian_name, :string, :limit => 15 #总监姓名
    add_column :users, :jobNm, :string, :limit => 30 #职位
    add_column :users, :mobile, :string, :limit => 30 #手机号
    add_column :users, :phone, :string, :limit => 15 #座机
    add_column :users, :orgNm, :string, :limit => 50 #部门
    add_column :users, :orgNo, :string, :limit => 20 #部门编号
    add_column :users, :parentNo, :string, :limit => 20 #上级部门编号
    add_column :users, :parentOrgNm, :string, :limit => 50 #上级部门名称
    add_column :users, :scoChrNm, :string, :limit => 50 #人事子范围名称
    add_column :users, :scoChrNo, :string, :limit => 20 #人事子范围编号
    add_column :users, :scoNm, :string, :limit => 50 #人事范围名称
    add_column :users, :scoNo, :string, :limit => 20 #人事范围名称
    add_column :users, :spm, :string, :limit => 50 #APP-SPM,可以为空，手机app的同学填写，部门经理填写
    add_column :users, :product, :string, :limit => 50 #负责的产品线
    add_column :users, :qq, :string, :limit => 15 #QQ
    add_column :users, :picture, :string #个人头像
  end
end
