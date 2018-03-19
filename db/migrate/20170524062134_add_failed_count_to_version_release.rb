class AddFailedCountToVersionRelease < ActiveRecord::Migration
  def change
    add_column :version_releases, :failed_count, :integer

    VersionRelease.completed.each{ |vr| vr.update_failed_count }
  end
end
