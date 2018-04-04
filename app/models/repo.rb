class Repo < ActiveRecord::Base
  has_and_belongs_to_many :projects
  validates :category, :url, presence: true
  validates :url, :uniqueness => true
  belongs_to :author, :class_name => 'User'
  REPO_CATEGORY = {:android => 10, :package => 20, :production => 30, :env => 40}

  after_save :update_name_and_branch

  default_scope { order(created_at: :desc) }
  scope :active, -> { where(abandoned: false) }

  def Repo.get_category_name(category)
    l("repo_category_#{Repo::REPO_CATEGORY.invert()[category]}")
  end

  def Repo.link(project_id, repo_id)
    sql = send(:sanitize_sql_array,
               ["INSERT INTO projects_repos(project_id, repo_id, author_id, created_at, updated_at)" +
                    "VALUES(?, ?, ?, now(), now())", project_id, repo_id, User.current.id])
    connection_pool.with_connection do |conn|
      conn.insert sql
    end
    return true
  end

  def Repo.unlink(project_id, repo_id)
    sql = send(:sanitize_sql_array,
               ["DELETE FROM projects_repos WHERE project_id=? AND repo_id=?", project_id, repo_id])
    connection.delete sql
  end

  def Repo.freeze(project_id, repo_id, status)
    sql = send(:sanitize_sql_array,
               ["UPDATE projects_repos SET freezed=? WHERE project_id=? AND repo_id=?", status, project_id, repo_id])
    connection.execute sql
  end

  def Repo.get_link(project_id)
    sql = send(:sanitize_sql_array,
               [self.projects_repos_select + " WHERE project_id=?", project_id])
    connection_pool.with_connection do |conn|
      conn.select_all sql
    end
  end

  def Repo.get_link_by_category(project_id, category)
    sql = send(:sanitize_sql_array,
               [self.projects_repos_select + " WHERE project_id=? and category=?", project_id, category])
    connection_pool.with_connection do |conn|
      conn.select_all sql
    end
  end

  def Repo.get_by_version_id(version_id)
    sql = send(:sanitize_sql_array,
               ["#{self.version_release_repos_select} WHERE a.id in (?) and h.category = ?",
                version_id, REPO_CATEGORY[:android]])
    connection_pool.with_connection do |conn|
      conn.select_all sql
    end
  end

  def Repo.get_freeze_status_by_repo_id(project_id, repo_id)
    sql = send(:sanitize_sql_array,
               [self.projects_repos_select + " WHERE project_id=? and repo_id=?", project_id, repo_id])
    connection_pool.with_connection do |conn|
      conn.select_all sql
    end
  end

  def Repo.get_thirdparty_version_release(thirdparty)
    sql = send(:sanitize_sql_array, ["#{self.thirdparty_version_release_repos(thirdparty)}"])
    connection_pool.with_connection do |conn|
      conn.select_all sql
    end
  end

  def to_s
    url.to_s
  end

  def update_name_and_branch
    url = self.url
    if /\Assh/ === url
      new_url = url.gsub('ssh://', 'ssh:')
      name = new_url.split("/")[1]
      branch = new_url.split("/")[2].present? ? new_url.split("/")[2] : "master"
    else
      name = nil 
      branch = nil
    end
    self.update_columns(:name => name, :branch => branch)
  end

private
  def self.projects_repos_select
    "SELECT a.freezed, a.project_id, a.repo_id, a.author_id, b.category, b.url FROM projects_repos" +
        " a left join repos b on a.repo_id=b.id"
  end

  def self.version_release_repos_select
    %[
      SELECT
        a.parent_id,
        a.project_id production_id ,
        b.`name` production_name ,
        a.id production_version_id ,
        a.`name` production_version_name,
        a.spec_id production_spec_id,
        c.`name` production_spec_name,
        d.spec_id project_spec_id,
        e.`name` project_spec_name,
        e.project_id,
        UPPER(f.identifier) project_name,
        f.android_platform,
        CONCAT(b.name, '_', a.name) version_fullname,
        -- f.`name` project_name,
        h.url repo_url
        /*, h.category repo_category,a.*, b.*, c.*, d.*, e.*, f.*, g.*, h.* */
      FROM
        versions a
      LEFT JOIN projects b ON b.id = a.project_id
      left join specs c on c.id = a.spec_id
      right join spec_versions d on (d.version_id=a.parent_id or d.version_id=a.id) and d.production_id=a.project_id and d.freezed = 0 and d.deleted = 0
      left join specs e on e.id = d.spec_id and e.freezed = 0 and e.for_new = 3 and e.deleted = 0
      left join projects f on f.id = e.project_id
      right join projects_repos g on g.project_id = e.project_id and g.freezed = 0
      left join repos h on h.id = g.repo_id
    ]
  end

  def self.thirdparty_version_release_repos(thirdparty)
    %[
      SELECT
        a.project_id      production_id,
        d.`name`          production_name,
        a.id              production_version_id,
        a.version_name    production_version_name,
        c.id              production_spec_id,
        c.`name`          production_spec_name,
        e.id              project_spec_id,
        e.`name`          project_spec_name,
        e.project_id,
        UPPER(f.identifier)    project_name,
        f.android_platform,
        CONCAT(d.name,'_',c.name, '_', a.version_name)    version_fullname,
        h.url             repo_url
      FROM (SELECT
              versions.id,
              versions.name          version_name,
              versions.spec_id,
              versions.project_id
            FROM versions
            WHERE versions.id IN (#{thirdparty.release_ids.join(',')})) a
        INNER JOIN (SELECT
                      specs.id                 spec_id,
                      spec_versions.spec_id    project_spec_id,
                      spec_versions.deleted,
                      spec_versions.freezed
                    FROM spec_versions
                      LEFT JOIN versions
                        ON versions.id = spec_versions.version_id
                      LEFT JOIN specs
                        ON specs.id = versions.spec_id
                    WHERE specs.name = '#{thirdparty.spec_name}') b
          ON a.spec_id = b.spec_id AND b.freezed = 0 AND b.deleted = 0
        INNER JOIN specs c
          ON c.id = a.spec_id
        INNER JOIN projects d
          ON d.id = a.project_id
        INNER JOIN specs e
          ON e.id = b.project_spec_id AND e.freezed = 0 AND e.for_new = 3 AND e.deleted = 0
        INNER JOIN projects f
          ON f.id = e.project_id
        INNER JOIN projects_repos g
          ON g.project_id = f.id AND g.freezed = 0
        INNER JOIN repos h
          ON h.id = g.repo_id AND h.category = 10
    ]
  end
end
