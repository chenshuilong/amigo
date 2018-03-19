class CreateSpecVersions < ActiveRecord::Migration
  def change
    create_table :spec_versions do |t|
      t.references :spec, index: true
      t.integer :production_id
      t.references :version, index: true
      t.boolean :deleted, default: 0
    end
  end
end
