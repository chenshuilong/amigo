class AddMokuaiToIssues < ActiveRecord::Migration
  def change
    add_column :issues, :mokuai_reason, :string
    add_column :issues, :mokuai_name, :string
    add_column :issues, :rom_version, :string
  end
end
