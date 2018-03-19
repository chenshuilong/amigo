class AddFieldsToProject < ActiveRecord::Migration
  def change
    add_column :projects, :category, :string
    add_column :projects, :hardware_group, :string
    add_column :projects, :approval_date, :text
    add_column :projects, :tone_date, :text
    add_column :projects, :producing_date, :text
    add_column :projects, :rom_version, :string
    add_column :projects, :mokuai_class, :integer
    add_column :projects, :product_serie, :string
  end
end
