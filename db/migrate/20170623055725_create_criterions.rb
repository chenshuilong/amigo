class CreateCriterions < ActiveRecord::Migration
  def change
    # created criterions
    create_table :criterions do |t|
      t.string :name
      t.string :identifier
      t.text :purpose
      t.text :description
      t.text :dept_range
      t.string :output_time
      t.text :settings
      t.boolean :active, default: true

      t.timestamps null: false
    end

    # create criterion_secondaries
    create_table :criterion_secondaries do |t|
      t.string :name
      t.string :sort
      t.string :target
      t.integer :parent_id
      t.boolean :active, default: true

      t.timestamps null: false
    end
  end
end
