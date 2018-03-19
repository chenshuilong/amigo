class AddJenkinsUrlToPatch < ActiveRecord::Migration
  def change
    add_column :patches, :jenkins_url, :text
    add_column :projects, :has_adapter_report, :boolean
    add_column :projects, :notes, :text
  end
end
