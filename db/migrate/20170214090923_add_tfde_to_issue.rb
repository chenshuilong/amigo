class AddTfdeToIssue < ActiveRecord::Migration
  def up
    add_column :issues, :tfde_id, :integer
    add_column :users, :pinyin, :string

    User.where("length(firstname) > 0").each do |user|
      user.update_column(:pinyin, user.to_pinyin)
    end
  end

  def down
    remove_column :issues, :tfde_id
    remove_column :users, :pinyin
  end
end
