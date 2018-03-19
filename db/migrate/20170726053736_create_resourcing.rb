class CreateResourcing < ActiveRecord::Migration
  def change
    create_table :resourcings do |t|
      t.references :user, index: true, foreign_key: true
      t.text :permissions
    end
  end
end
