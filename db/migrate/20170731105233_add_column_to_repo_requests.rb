class AddColumnToRepoRequests < ActiveRecord::Migration
  def change
    add_column :repo_requests, :tag_number, :string, :after => :version_id
  end
end
