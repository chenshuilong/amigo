class AddDetailsToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :external_name, :string
    add_column :projects, :cta_name, :string
  end
end
