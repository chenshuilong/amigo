class AddFieldToDefinitionAltterRecord < ActiveRecord::Migration
  def change
    add_column :definition_alter_records, :definition_version, :string
  end
end
