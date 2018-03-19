class AddExtraFieldsToVersion < ActiveRecord::Migration
  def change
    change_column :versions, :description, :text, :default => nil, :null => true
    add_column :versions, :production_name, :string
    add_column :versions, :baseline, :text # 源码信息
    add_column :versions, :label, :text
    add_column :versions, :path, :text # 版本路径（镜像包地址）
  end
end
