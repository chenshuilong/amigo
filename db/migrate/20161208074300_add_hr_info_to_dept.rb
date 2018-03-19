class AddHrInfoToDept < ActiveRecord::Migration
  def change
    add_column :depts, :manager_id, :integer # Jingli
    add_column :depts, :sub_manager_id, :integer # Fujingli
    add_column :depts, :supervisor_id, :integer # Zhuguan
    add_column :depts, :majordomo_id, :integer # Zongjian
    add_column :depts, :vice_president_id, :integer # Fuzong
  end
end
