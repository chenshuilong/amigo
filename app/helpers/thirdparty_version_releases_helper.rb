module ThirdpartyVersionReleasesHelper
  include ProjectsHelper

  def release_heading(third)
    h("#{third.spec.name}_#{third.created_at.strftime('%Y%m%d')}")
  end

  def software_release_path
    "\\\\18.8.8.2\\software_release\\Applications"
  end

  def version_by_fullname(fullname)
    Version.joins(:project, :spec).where(:specs => {:deleted => false}).where("concat(projects.name,'_',specs.name,'_',versions.name) = '#{fullname}'")
  end

  def title_by_category(cate)
    case cate
      when Thirdparty::Thirdparty_CATEGORY[:preload] then
        l(:project_production_type_3rd_version_release)
      when Thirdparty::Thirdparty_CATEGORY[:resource] then
        l(:project_production_type_resource_version_release)
      else
        ""
    end
  end

end
