class CreateFlowFile < ActiveRecord::Migration
  def change
    create_table :flow_files do |t|
      t.string   :no
      t.string   :name
      t.string   :version
      t.integer  :file_type_id
      t.string   :file_type_name
      t.string   :file_type_code
      t.integer  :file_status_id
      t.string   :file_status_name
      t.text     :use
      t.text     :notes
      t.integer  :author_id

      t.timestamps :null => false
    end

    create_table :flow_file_types do |t|
      t.string  :name
      t.string  :code
      t.integer :author_id

      t.timestamps :null => false
    end

    create_table :flow_file_statuses do |t|
      t.string  :name
      t.boolean :editable, default: true
      t.integer :author_id

      t.timestamps :null => false
    end

    create_table :flow_file_attachments do |t|
      t.integer :flow_file_id
      t.integer :attachment_id
      t.integer :parent_flow_file_id
      t.integer :author_id
      t.string  :status

      t.timestamps :null => false
    end

    add_column :attachments, :deleted, :boolean, default: false
    add_column :attachments, :deleted_by_id, :integer
    add_column :attachments, :deleted_at, :datetime

    add_index :flow_files, :file_type_id
    add_index :flow_files, :file_status_id
    add_index :flow_files, :author_id
    add_index :flow_file_types, :author_id
    add_index :flow_file_statuses, :author_id
    add_index :flow_file_attachments, :flow_file_id
    add_index :flow_file_attachments, :attachment_id
    add_index :flow_file_attachments, :author_id

    #flow_file_status = FlowFileStatus.new(name: "废弃", editable: false)
    #flow_file_status.save
  end
end
