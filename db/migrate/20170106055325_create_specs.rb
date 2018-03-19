class CreateSpecs < ActiveRecord::Migration
  def change
    create_table :specs do |t|
      t.references :project, index: true, foreign_key: true
      t.string :name
      t.datetime :jh_collect_finish_dt
      t.datetime :sj_collect_finish_dt
      t.boolean :deleted, default: 0 # default value is 0 --undeleted
      t.boolean :locked, default: 0 # default value is 0 --unlocked
      t.boolean :is_default, default: 0
      t.text :note

      t.timestamps null: false
    end
  end
end
