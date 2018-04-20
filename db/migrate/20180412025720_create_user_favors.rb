class CreateUserFavors < ActiveRecord::Migration
  def change
    create_table :user_favors do |t|
      t.references :user, index: true, foreign_key: true
      t.string :title
      t.string :url
      t.integer :sort
      t.integer :status, default: 1

      t.timestamps null: false
    end
  end
end
