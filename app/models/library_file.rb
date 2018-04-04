class LibraryFile < ActiveRecord::Base
  belongs_to :library
  belongs_to :user

  scope :libraries, lambda{ |patch_id|
    select("libraries.id, libraries.name, libraries.path, libraries.status, users.firstname")
    .joins(:library, :user)
    .where("libraries.container_id = #{patch_id} AND libraries.container_type = 'Patch'")
    .group(:library_id)
    .reorder("library_files.created_at desc")
  }

  scope :conflict_files, lambda{ |patch_id|
    select("libraries.id lib_id, libraries.name lib_name, libraries.path, users.firstname,
            #{table_name}.library_id, #{table_name}.name, #{table_name}.conflict_type, #{table_name}.user_id,
            case when #{table_name}.status = 'success' then '成功' else '失败' end status ")
    .joins(:library, :user)
    .where("libraries.container_id = #{patch_id} AND libraries.container_type = 'Patch'")
    .reorder("library_files.created_at desc")
  }

  def update_file_infos(new_status)
    result = LibraryFile.transaction do 
      self.update(status: new_status)
      @record = AlterRecord.new(alter_for: library.container, notes: "gionee_update 升级分支失败结果更新")
      @record.details.build(value: "Name: #{library.name}, Path: #{library.path}, File: #{name}文件报错，#{user.firstname} 已修改文件状态为成功! ")
      @record.save
      rest_failed = library.library_files.where(status: 'failed')
      if rest_failed.count == 0
        library.update_status_by_files("update_failed", "update_success")
      end
    end

    return status
  end
end
