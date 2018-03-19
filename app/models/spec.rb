# -*- encoding : utf-8 -*-

class Spec < ActiveRecord::Base

  has_many :spec_versions
  has_many :app_lists, class_name: "SpecVersion", foreign_key: "spec_id"
  has_many :versions
  has_many :spec_alter_records
  has_many :version_publishes, class_name:"VersionPublish", foreign_key: "spec_id"
  belongs_to :project
  has_one :thirdparty
  before_save :remove_blank_for_name

  validates_presence_of :name

  default_scope { order(deleted: :asc, is_default: :desc, created_at: :desc) }
  scope :undeleted, -> { where(deleted: false) }
  scope :loccked, -> { where(locked: true) }
  scope :default, -> { where(is_default: true) }
  scope :thirdparty, -> { where(is_default: true) }

  scope :apps, lambda { |sql|
    joins("inner join spec_versions on #{table_name}.id = spec_versions.spec_id
           left join projects app on app.id = spec_versions.production_id and app.category = #{Project::CATEGORY_APP}
           left join versions on versions.id = spec_versions.version_id
           left join specs as app_spec on versions.spec_id = app_spec.id
           left join projects spec_project on spec_project.id = specs.project_id")
        .where("spec_versions.deleted = 0 and app.production_type <> #{Project::PROJECT_PRODUCTION_TYPE[:other]}
            and #{sql.blank? ? '1=1' : sql}").undeleted
  }

  scope :pd_apps, lambda { |sql, production_id|
    joins("LEFT JOIN spec_versions ON #{table_name}.id = spec_versions.spec_id AND spec_versions.production_id = #{production_id} AND spec_versions.deleted = 0
           LEFT JOIN projects app ON app.id = spec_versions.production_id AND app.category = #{Project::CATEGORY_APP} AND app.production_type <> #{Project::PROJECT_PRODUCTION_TYPE[:other]}
           LEFT JOIN versions ON versions.id = spec_versions.version_id
           LEFT JOIN #{table_name} AS app_spec ON versions.spec_id = app_spec.id
           LEFT JOIN projects spec_project ON spec_project.id = #{table_name}.project_id")
    .where("#{sql.blank? ? '1=1' : sql}")
    .select("app.name as app_name,CONCAT(spec_project.name,specs.name) spec_name,spec_project.ownership,
             CASE WHEN app.production_type = 4 THEN app_spec.name ELSE CONCAT(app_spec.name,'_',REPLACE(versions.name,CONCAT('.',SUBSTRING_INDEX(versions.name,'.',-1)),'')) END as app_version,
             #{table_name}.for_new,#{table_name}.freezed,ifnull(spec_versions.id,0) as app_id,specs.id as spec_id,
             spec_versions.production_id,DATE_FORMAT(spec_versions.updated_at,'%Y-%m-%d %H:%i:%s') app_updated_on,
             #{table_name}.note,spec_versions.mark,spec_versions.cn_name,spec_versions.desktop_name,spec_versions.developer").undeleted
  }

  scope :select_apps, lambda { |sql| apps(sql).select("app.name as app_name,CONCAT(spec_project.name,specs.name) spec_name,spec_project.ownership,
    CASE WHEN app.production_type IN (4, 6) THEN app_spec.name ELSE CONCAT(app_spec.name,'_',REPLACE(versions.name,CONCAT('.',SUBSTRING_INDEX(versions.name,'.',-1)),'')) END as app_version,release_path,
    #{table_name}.for_new,#{table_name}.freezed,spec_versions.id as app_id,specs.id as spec_id,spec_versions.version_id,spec_versions.freezed app_freezed,
    spec_versions.production_id,DATE_FORMAT(spec_versions.updated_at,'%Y-%m-%d %H:%i:%s') app_updated_on,
    DATE_FORMAT(#{table_name}.jh_collect_finish_dt,'%Y-%m-%d %H:%i:%s') as jh_collect_finish_dt,
    DATE_FORMAT(#{table_name}.sj_collect_finish_dt,'%Y-%m-%d %H:%i:%s') as sj_collect_finish_dt,
    #{table_name}.note,spec_versions.mark,spec_versions.cn_name,spec_versions.desktop_name,spec_versions.developer").order("app.name") }

  #version search of spec with project-name-list&&project-category
  scope :version_search, lambda { |category, list|
    joins(:project).where(projects: {:id => list, :category => category.present? ? (category == 'other' ? [4] : [1, 2, 3]) : [1,2,3,4]})
    .select("specs.id, specs.name, project_id, projects.name AS project_name, GROUP_CONCAT( CONCAT_WS(',', specs.name, specs.id) SEPARATOR ',') as specs_list, specs.deleted")
    .where("specs.deleted = 0")
    .group("project_id")
  }
  scope :search_apps, lambda { |list|
    joins("inner join spec_versions on #{table_name}.id = spec_versions.spec_id
           left join projects on projects.id = spec_versions.production_id
           left join versions on versions.id = spec_versions.version_id
           left join specs as app_spec on versions.spec_id = app_spec.id")
    .where("projects.id #{list.present? ? 'in('+ list.join(",")+')' : '' }").select("projects.name as app_name,
    CASE WHEN app.production_type = 4 THEN app_spec.name ELSE CONCAT(app_spec.name,'_',REPLACE(versions.name,CONCAT('.',SUBSTRING_INDEX(versions.name,'.',-1)),'')) END as app_version,
    spec_versions.id as app_id, spec_versions.version_id,
    spec_versions.production_id").order("projects.name") }

  #search spec author
  scope :search_author, lambda { |author|
    joins(:spec_alter_records)
    .where("specs.id IN (select a.spec_id from spec_alter_records a, (select spec_id, min(created_at) created_at from spec_alter_records group by spec_id) b
            where a.user_id = #{author} and a.created_at = b.created_at and a.prop_key = 'spec_name' and a.record_type = 0
            order by a.spec_id)")
    .group("spec_id")}
  #get specs group by project
  scope :group_spec, lambda { |project_ids, spec_ids|
    joins(:project).where(projects: {id: project_ids, :category => [1, 2, 3]}, id: spec_ids)
    .select("specs.id, specs.name, project_id, projects.name AS project_name, GROUP_CONCAT( CONCAT_WS(',', specs.name, specs.id) SEPARATOR ',') as specs_list")
    .group("project_id")}
  def self.check_app_spm_by_current_user_and_project(user = User.current, project_id)
    rows = Role.spm_users("roles.name = 'APP-SPM'
      and users.id = #{user.id} and projects.id = #{project_id}")
    rows && rows.count > 0 ? true : false
  end

  def fullname
    project.name + "_" + name
  end

  private

  def remove_blank_for_name
    self.name.strip!
  end
end
