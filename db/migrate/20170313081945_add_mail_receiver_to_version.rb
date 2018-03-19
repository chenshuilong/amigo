class AddMailReceiverToVersion < ActiveRecord::Migration
  def change
    add_column :versions,         :mail_receivers, :string
    add_column :version_releases, :mail_receivers, :string
  end
end
