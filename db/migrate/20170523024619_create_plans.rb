class CreatePlans < ActiveRecord::Migration
  def change
    create_table :plans do |t|
      t.integer :project_id
      t.integer :parent_id
      t.integer :lft
      t.integer :rgt
      # t.integer :level            # 树的等级
      t.string  :name             # 项目计划名称
      t.date    :plan_start_date  # 计划开始时间
      t.date    :plan_due_date    # 计划完成时间
      t.integer :assigned_to_id   # 指派给
      t.integer :check_user_id    # 确认人
      t.text    :description      # 描述
      t.integer :priority         # 优先级
      t.integer :author_id        # 作者

      t.timestamps null: false
    end
  end
end
