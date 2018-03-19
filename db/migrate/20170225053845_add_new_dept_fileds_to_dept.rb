class AddNewDeptFiledsToDept < ActiveRecord::Migration
  def change
    add_column :depts, :comNm,                  :string # 公司
    add_column :depts, :parentNm,               :string # 上级部门名称
    add_column :depts, :manager_number,         :string # 经理工号
    add_column :depts, :manager_name,           :string # 经理名称
    add_column :depts, :manager2_number,        :string # 经理2工号
    add_column :depts, :manager2_name,          :string # 经理2名称
    add_column :depts, :sub_manager_number,     :string # 副经理1工号
    add_column :depts, :sub_manager_name,       :string # 副经理1名称
    add_column :depts, :sub_manager2_number,    :string # 副经理1工号
    add_column :depts, :sub_manager2_name,      :string # 副经理1名称
    add_column :depts, :supervisor_number,      :string # 主管1工号
    add_column :depts, :supervisor_name,        :string # 主管1名称
    add_column :depts, :supervisor2_number,     :string # 主管2工号
    add_column :depts, :supervisor2_name,       :string # 主管1名称
    add_column :depts, :majordomo_number,       :string # 总监工号
    add_column :depts, :majordomo_name,         :string # 总监名称
    add_column :depts, :sub_majordomo_number,   :string # 副总监工号
    add_column :depts, :sub_majordomo_name,     :string # 副总监名称
    add_column :depts, :vice_president_number,  :string # 主管副总工号
    add_column :depts, :vice_president_name,    :string # 主管副总名称
    add_column :depts, :vice_president2_number, :string # 主管副总工号
    add_column :depts, :vice_president2_name,   :string # 主管副总名称
  end
end
