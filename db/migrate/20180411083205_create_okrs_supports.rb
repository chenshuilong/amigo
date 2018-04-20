class CreateOkrsSupports < ActiveRecord::Migration
  def change
    create_table :okrs_supports do |t|
      t.integer :user_id
      t.string  :user_name
      t.integer :okrs_record_id
      t.integer :okrs_object_id
      t.integer :container_id
      t.string  :container_type

      t.timestamps null: false
    end

    remove_column :okrs_key_results, :supported_by, :text
  end
end
