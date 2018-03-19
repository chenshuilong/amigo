class CreateProjectsRepos < ActiveRecord::Migration
  def change
    create_table :projects_repos do |t|
      t.integer :project_id, null:false, comment: '项目编号'
      t.integer :repo_id, null:false, comment: '代码仓编号'
      t.integer :author_id, null:false
      t.timestamps null: false
    end
  end
end
