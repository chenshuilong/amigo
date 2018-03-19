class AddFiledsToThirdparty < ActiveRecord::Migration
  def change
    add_column :thirdparties, :result, :text

    add_column :projects, :cn_name, :string
    add_column :projects, :config_info, :string
  end
end
