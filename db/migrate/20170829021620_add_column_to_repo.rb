class AddColumnToRepo < ActiveRecord::Migration
  def change
    add_column :repos, :abandoned, :boolean, :default => false, :null => false, :after => :branch
    add_column :version_releases, :has_problem, :boolean, :default => false
  end
end
