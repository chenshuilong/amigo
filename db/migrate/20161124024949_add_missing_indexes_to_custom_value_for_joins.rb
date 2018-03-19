class AddMissingIndexesToCustomValueForJoins < ActiveRecord::Migration
  def change
    say_with_time "Adding indexes on custom_values, this may take some time..." do
      add_index :custom_values, [:customized_id, :custom_field_id, :customized_type],:name => "index_custom_fields_for_joins"
    end
  end
end
