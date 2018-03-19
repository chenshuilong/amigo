class SpecVersion < ActiveRecord::Base
  belongs_to :spec
  belongs_to :version
  belongs_to :production

  after_save :check_production_id

  default_scope { order(created_at: :desc) }
  scope :undeleted, -> { where(deleted: false) }

  #get spec compare with projects/specs
  scope :search, lambda { |specs|
    joins("left join projects on projects.id = spec_versions.production_id
           left join versions on versions.id = spec_versions.version_id
           left join specs  on specs.id = spec_versions.spec_id
           left join (versions as v left join specs as s on v.spec_id=s.id) on v.id=spec_versions.version_id")
    .where("versions.id != 0 AND projects.id != 0 AND spec_versions.deleted = 0")
    .where(spec_id: specs)
    .select("count(specs.id) as specs_count, projects.name as app_name, projects.identifier as identifier, production_id, specs.id as spec_id, count(v.id) as v_count, COUNT(DISTINCT v.id) as v_uniq, GROUP_CONCAT(DISTINCT v.id) as v_ids, GROUP_CONCAT( CONCAT_WS(',', specs.id, CONCAT_WS('_', s.name, v.name)) ORDER BY v.name SEPARATOR ',') as app_versions")
    .group("production_id")
    .reorder("v_count ASC, CASE WHEN COUNT(v.id) >= #{specs.try(:count).to_i} THEN COUNT(DISTINCT v.id) END DESC, GROUP_CONCAT( CONCAT_WS('', s.name, v.name) ORDER BY s.name ASC, v.name ASC SEPARATOR '' )")
  }

  #search VersionPublish apk_info by sql
  scope :version_publish_apk_info, lambda{ |spec, version, sql|
    select("spec_versions.id, app.name as app_name, REPLACE(versions.name,CONCAT('.',SUBSTRING_INDEX(versions.name,'.',-1)),'') as app_version, applists.apk_name, applists.apk_permission, applists.apk_removable, spec_versions.deleted")
    .from("(select production_id, max(spec_versions.created_at) as maxcreated_at
         from spec_versions
         where spec_versions.spec_id = #{spec}
         group by production_id
      ) as x")
    .joins("inner join spec_versions on spec_versions.production_id = x.production_id and spec_versions.created_at = x.maxcreated_at
            inner join projects app on app.id = spec_versions.production_id and app.category = 4 and app.production_type <> 4
            left join versions on versions.id = spec_versions.version_id
            left join version_applists applists on applists.version_id = #{version} AND CONCAT(app.name, '.apk') = applists.apk_name")
    .where("#{sql}")
  }

  #search VersionPublish rows by sql
  scope :version_publish_row, lambda{ |spec, sql|
    select("spec_versions.id, cn_name, desktop_name, mark, developer, app.name")
    .from("(select production_id, max(spec_versions.created_at) as maxcreated_at
            from spec_versions
            where spec_versions.spec_id = #{spec}
            group by production_id
           ) as x")
    .joins("inner join spec_versions on spec_versions.production_id = x.production_id and spec_versions.created_at = x.maxcreated_at
            inner join projects app on app.id = spec_versions.production_id and app.category = 4 and app.production_type <> 4")
    .where("#{sql}")
  }

  def self.collect_all_app_list(spec_id, project)
    # Create All APPs For Default unless collect never before
    # Only apk and framework and preload
    spec = Spec.find(spec_id)

    if spec && !spec.is_colleted
      Production.active.each do |pd|
        if pd.production_type.in?([Project::PROJECT_PRODUCTION_TYPE[:app], Project::PROJECT_PRODUCTION_TYPE[:framework], Project::PROJECT_PRODUCTION_TYPE[:preload]])
          SpecVersion.create(:spec_id => spec_id, :version_id => 0,
                             :production_id => pd.id, :desktop_name => "无",
                             :developer => "深圳市金立通信设备有限公司") if pd.ownership == project.ownership && SpecVersion.where("spec_id = #{spec_id} and production_id = #{pd.id}").blank?
        end
      end
    end
  end

  def self.app_list_with_successful_version(spec_id)
    where("#{table_name}.spec_id = #{spec_id} and #{table_name}.version_id > 0 and #{table_name}.deleted = 0")
  end

  def self.copy_all_app_to_project(copy_type, cppy_spec_id, to_spec_id)
    SpecVersion.undeleted.where(:spec_id => cppy_spec_id).each do |app|
      copy = SpecVersion.new
      copy.production_id = app.production_id || (app.version_id ? Version.find(app.version_id).project_id : 0)
      copy.spec_id = to_spec_id
      # Only copy production name when the same project, else copy applist
      if copy_type.to_i == 1
        copy.version_id = app.version_id
        copy.release_path = app.release_path
        copy.cn_name = app.cn_name
        copy.desktop_name = app.desktop_name
        copy.developer = app.developer
        copy.mark = app.mark
      end
      copy.save
    end

    # Can't collect apps after copy spec
    spec = Spec.find(to_spec_id)
    spec.is_colleted = true
    spec.save
  end

  def version_name(i)
    versions = app_versions.split(",")
    ver_hash = Hash[versions.each_slice(2).to_a]
    ver_hash[i.to_s].present? ? ver_hash[i.to_s].split(".").to(-2).join(".") : '-'
  end

  def self.generate_rows_json
    rows = {}
    self.all.each do |row|
      rows[row.name.squish] = {"cn_name": row.cn_name.to_s, "desktop_name": row.desktop_name.to_s, "description": row.mark.to_s, "developer": row.developer.to_s, "type": "local"}
    end
    return rows
  end

  def self.generate_apk_info
    @apk_infos = self.all
    lists = VersionPermission.where.not(deleted:true, name:"remove_notes").pluck(:name, :meaning).to_h
    content = {}
    rows = {}
    @apk_infos.each do |apk_info|
      list = []
      if apk_info.apk_permission.present?
        @permissions = apk_info.apk_permission.split(";")
        @permissions.each do |per|
          list.push(lists[per].present? ? lists[per] : per) 
        end
      end
      apk_permission = list.join(" ")
      apk_removable = apk_info.apk_removable == 0 ? "否" : "是"
      rows[apk_info.app_name.squish] = {"id": apk_info.id, "app_name": apk_info.app_name, "app_version": apk_info.app_version, "apk_permission": apk_permission, "apk_removable": apk_removable, "deleted": apk_info.deleted}
    end
    return rows
  end

  def check_production_id
    self.production_id = Version.find(version_id).project_id if self.production_id.nil?
  end

end
