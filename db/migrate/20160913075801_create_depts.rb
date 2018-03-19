class CreateDepts < ActiveRecord::Migration
  def change
    create_table :depts do |t|
      t.string :orgNm
      t.string :orgNo
      t.string :parentNo

      t.timestamps null: false
    end
  end
end
