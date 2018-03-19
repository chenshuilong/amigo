class ChangeColumnsTypeOfLibraryFile < ActiveRecord::Migration
  def change
    change_column :library_files, :name, :text
    change_column :library_files, :conflict_type, :text
  end
end
