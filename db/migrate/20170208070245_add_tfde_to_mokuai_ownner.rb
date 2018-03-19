class AddTfdeToMokuaiOwnner < ActiveRecord::Migration
  def change
    add_column :mokuai_ownners, :tfde, :integer
    add_column :mokuais, :default_tfde, :integer
    add_column :projects, :production_type, :integer
  end
end
