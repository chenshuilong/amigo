class AddColumnToRepoRequest < ActiveRecord::Migration
  def change
    add_column :repo_requests, :repo_name, :string, :after => :use
    add_column :repo_requests, :production_type, :string, :after => :use
  end
end
