class ChangeProjectsReposFields < ActiveRecord::Migration
  def change
    remove_column :projects_repos, :id, :integer
    add_index :projects_repos, [:project_id, :repo_id], :name => :projects_repos_unique, :unique => true
  end
end
