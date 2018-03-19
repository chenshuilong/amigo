class AddFieldsToProjectsRepos < ActiveRecord::Migration
  def change
    add_column :specs, :freezed, :boolean, default: 0            #冻结 0: unfreezed, 1: freezed
    add_column :specs, :for_new, :boolean, default: 1            #类型 0: after andriod n, 1: before andriod n

    add_column :projects_repos, :freezed, :boolean, default: 1 # 1 default: freezed
  end
end
