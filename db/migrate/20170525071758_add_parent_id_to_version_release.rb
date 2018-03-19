class AddParentIdToVersionRelease < ActiveRecord::Migration
  def change
    add_column :version_releases, :parent_id, :integer
    add_column :version_releases, :ued_check_result, :text
    add_column :version_releases, :sqa_check_result, :text
    add_column :version_releases, :additional_note, :text

    VersionRelease.where('category = 2').each do |vr|
      pid = vr.find_parent
      vr.update_column(:parent_id, pid) if pid.present?
    end
  end
end
