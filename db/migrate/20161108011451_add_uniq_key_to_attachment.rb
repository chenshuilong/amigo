class AddUniqKeyToAttachment < ActiveRecord::Migration
  def change
    add_column :attachments, :uniq_key, :string
    add_column :attachments, :ftp_ip, :string
  end
end
