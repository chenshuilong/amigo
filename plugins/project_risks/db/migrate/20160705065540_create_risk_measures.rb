class CreateRiskMeasures < ActiveRecord::Migration
  def change
    create_table :risk_measures do |t|
      t.references :risk, index: true, foreign_key: true
      t.text :content
      t.datetime :finish_at

      t.timestamps null: false
    end
  end
end
