class CreateVersionApplists < ActiveRecord::Migration
  def change
    create_table :version_applists do |t|
      t.references :version, index: true
      t.integer :app_version_id
      t.timestamps null: false
    end
  end
end
