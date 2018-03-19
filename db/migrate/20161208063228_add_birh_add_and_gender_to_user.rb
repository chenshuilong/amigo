class AddBirhAddAndGenderToUser < ActiveRecord::Migration
  def change
    add_column :users, :gender, :boolean
    add_column :users, :native_place, :string
    add_column :users, :married, :string
    add_column :users, :entry_date, :date
  end
end
