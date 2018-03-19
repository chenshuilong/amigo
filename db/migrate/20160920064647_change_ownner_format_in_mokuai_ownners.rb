class ChangeOwnnerFormatInMokuaiOwnners < ActiveRecord::Migration
  def up
    change_column :mokuai_ownners, :ownner, :text
  end

  def down
    change_column :mokuai_ownners, :ownner, :integer
  end
end
