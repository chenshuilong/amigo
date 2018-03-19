class VersionApplist < ActiveRecord::Base

  validates :version_id, :uniqueness => { scope: [:app_version_id, :apk_name], :message => :already_exists }

  belongs_to :version, :class_name => 'Version'
  belongs_to :app_version, :class_name => 'Version', foreign_key: 'app_version_id'

  scope :two_version_compare, lambda { |sql|
    joins("INNER JOIN versions ON versions.id = version_applists.version_id
           INNER JOIN versions AS app_version ON app_version.id = version_applists.app_version_id
           LEFT JOIN projects AS production ON app_version.project_id = production.id
           LEFT JOIN specs ON app_version.spec_id = specs.id")
    .select("version_applists.id, production.id as pid, production.name as pname, production.identifier as p_identifier,
    	       group_concat(DISTINCT(app_version_id) separator ',') as app_version_ids,
    	       group_concat(CONCAT_WS(',', version_id, versions.project_id, versions.spec_id,  REPLACE(app_version.name,CONCAT('.',SUBSTRING_INDEX(app_version.name,'.',-1)),''), 
             CONCAT_WS('_', specs.name, app_version.name), app_version.id) order by version_id asc separator ';') as list")
    .where("#{sql}").group("production.id").reorder("production.name")}

  scope :apk_size_compare, lambda { |sql|
    select("apk_name, group_concat(version_id) AS version_ids, group_concat(CONCAT_WS(',', version_id, apk_size, apk_interior_version) order by version_id asc separator ';') as list")
    .where("#{sql}")
    .group("apk_name")
  }
  scope :infos_by_apk_base, lambda{ |version|
    select("va.apk_name, va.apk_size, va.apk_interior_version, va.apk_uploaded, va.apk_removable, va.apk_cn_name, va.apk_desktop, 
            ab.app_category, ab.id, ab.name, ab.removable, ab.cn_name, ab.desktop_name, ab.notes")
    .from("version_applists as va")
    .joins("LEFT JOIN apk_bases as ab ON ab.name = va.apk_name")
    .where("version_id = #{version}")
  }

  def self.compare_list_hash
    @applists = self.all

    result = []
    @applists.each do |applist|
    	applist_hash = {}
      applist_hash[:p_id] = applist.pid
      applist_hash[:p_name] = applist.pname
      applist_hash[:p_identifier] = applist.p_identifier
      applist_hash[:app_version_ids] = applist.app_version_ids
      applist_hash[:list] = {}
      applist.list.split(";").each  do |item|
      	items = item.split(",")
        list_hash = {}
        list_hash[items[0]] = {project_id: items[1], spec_id: items[2], version_name: items[3], app_version_name: items[4], app_version_id: items[5]}
        applist_hash[:list].merge!(list_hash)
      end

      result << applist_hash
    end

    return result
  end

  def self.generate_apk_info
    lists = VersionPermission.where.not(deleted:true, name:"remove_notes").pluck(:name, :meaning).to_h
    content = {}
    rows = {}
    self.all.includes(:version).each do |apk|
      next unless apk.apk_name.present?
      list = []
      if apk.apk_permission.present?
        @permissions = apk.apk_permission.split(";")
        @permissions.each do |per|
          list.push(lists[per].present? ? lists[per] : per) 
        end
      end
      apk_permission = list.join(", ")
      apk_removable = apk.apk_removable ? "是" : "否"
      rows[apk.apk_name.squish] = {v_name: apk.version.name, app_version: apk.apk_interior_version, apk_cn_name: apk.apk_cn_name, apk_desktop: apk.apk_desktop, 
                                   apk_permission: apk_permission, apk_removable: apk_removable, apk_uploaded: apk.apk_uploaded}
    end

    return rows
  end

  #generate and compare apk_info base on version_applist for version_publish
  def self.generate_applist_infos(publish=nil)
    @apk_lists = generate_apk_info

    return {}, {}, [{}] unless @apk_lists.present?

    @apks = ApkBase.all
    
    rows = {}
    full_rows = {}
    notes = {}

    #与上一个版本的apk_lists进行对比，包括增加/减少的APK及是否上传到官网信息改变
    if publish.present?
      @last_apk_infos = publish.version.app_lists.generate_apk_info
      last_apks = publish.version.app_lists.map(&:apk_name)
      current_apks = @apk_lists.keys

      adds = current_apks - last_apks
      deletes = last_apks - current_apks
      sames = current_apks & last_apks

      notes[:changes] = []
      #增加的APK
      if adds.present?
        adds.each do |a|
          apk_name = a.to_s.squish
          apk_uploaded = @apk_lists[apk_name][:apk_uploaded]
          v_name = @apk_lists[apk_name][:v_name]
          notes[:changes] << {:apk_name => apk_name, :v_name => v_name, :apk_uploaded => apk_uploaded, :type => 'add'}
        end
      end

      #减少的APK
      if deletes.present?
        deleted_apks = []
        deletes.each do |d|
          apk_name = d.to_s.squish
          apk_uploaded = @last_apk_infos[apk_name][:apk_uploaded]
          v_name = @last_apk_infos[apk_name][:v_name]
          notes[:changes] << {:apk_name => apk_name, :v_name => v_name, :apk_uploaded => apk_uploaded, :type => 'delete'}
        end
      end

      #是否上传到官网信息改变
      if sames.present?
        changed_apks = []
        sames.each do |s|
          apk_name = s.to_s.squish
          last_apk_uploaded = @last_apk_infos[apk_name][:apk_uploaded]
          current_apk_uploaded = @apk_lists[apk_name][:apk_uploaded]
          last_v_name = @last_apk_infos[apk_name][:v_name]
          current_v_name = @apk_lists[apk_name][:v_name]
          if last_apk_uploaded != current_apk_uploaded
            notes[:changes] << {:apk_name => apk_name,
                                :old => {:v_name => last_v_name, :apk_uploaded => last_apk_uploaded}, 
                                :new => {:v_name => current_v_name, :apk_uploaded => current_apk_uploaded},
                                :type => 'change'}
          end
        end
      end
    end


    without_apk = []
    without_content = []

    @apk_lists.each do |k, v|
      apk_name = k.to_s.squish
      info = @apks.find_by(name: apk_name)
      info_exist = info.present?

      description  = info.try(:cn_description).to_s
      developer    = info.try(:developer).to_s

      # 获取中文名
      if v[:apk_cn_name].blank? || v[:apk_cn_name] == 'null'
        cn_name = info_exist ? info.try(:cn_name).to_s : '无'
      else
        cn_name = v[:apk_cn_name]
      end

      # 获取桌面名称
      if v[:apk_desktop] == false
        desktop_name = '无'
      else
        if v[:apk_cn_name].blank? || v[:apk_cn_name] == 'null'
          desktop_name = info_exist ? info.try(:cn_name).to_s : '无'
        else
          desktop_name = v[:apk_desktop] ? v[:apk_cn_name] : '无'
        end
      end

      missing = info_exist ? !(info.cn_description.present? && info.developer.present?) : true

      if v[:apk_uploaded]
        rows[apk_name] = {"cn_name": cn_name, "desktop_name": desktop_name, "description": description, "developer": developer, "exist": info_exist, "missing": missing}
        full_rows[apk_name] = {"cn_name": cn_name, "desktop_name": desktop_name, "description": description, "developer": developer, "apk_name": apk_name,
                               "apk_version": v[:app_version], "apk_permission": v[:apk_permission], "apk_removable": v[:apk_removable], "exist": info_exist, "missing": missing}

        without_apk << {:apk_name => apk_name, :apk_uploaded => v[:apk_uploaded]} unless info_exist
        without_content << {:apk_name => apk_name, :apk_uploaded => v[:apk_uploaded]} if info_exist && missing
      else
        without_apk << {:apk_name => apk_name, :apk_uploaded => v[:apk_uploaded]} unless info_exist
        without_content << {:apk_name => apk_name, :apk_uploaded => v[:apk_uploaded]} if info_exist && missing
      end
      notes[:without_apk] = without_apk if without_apk.present?
      notes[:without_content] = without_content if without_content.present?
    end
 
    return rows, full_rows, [notes]
  end

  def self.apk_version_list(va, vb)
    @apklists = self.all

    result = []
    @apklists.each do |apk|
      apklist_hash = {}
      apklist_hash[:apk_name] = apk.apk_name
      apklist_hash[:list] = {}
      apk.list.split(";").each  do |item|
        items = item.split(",")
        list_hash = {}
        list_hash[items[0]] = {version_id: items[0].to_i, apk_interior_version: items[2].to_s}
        apklist_hash[:list].merge!(list_hash)
      end

      result << apklist_hash
    end

    @lists = []
    if result.present?
      #only va
      @only_va = result.select{|a| a[:list].keys.length == 1 && a[:list].keys.include?(va.to_s)}
      #only vb
      @only_vb = result.select{|a| a[:list].keys.length == 1 && a[:list].keys.include?(vb.to_s)}
      #both va, vb
      @both = result.select{|a| a[:list].keys.length == 2}
      
      @lists = @only_va + @only_vb + @both
    end

    return @lists
  end

  def self.apk_size_list(va, vb)
    @apklists = self.all

    result = []

    @apklists.each do |apk|
      apklist_hash = {}
      apklist_hash[:apk_name] = apk.apk_name
      apk_lists = apk.list.split(";").map{|a| [a.split(",")[0], {size: a.split(",")[1], v: a.split(",")[2]}]}.to_h
      apklist_hash[:va] = apk_lists[va.to_s].present? ? apk_lists[va.to_s][:size].to_i : '-'
      apklist_hash[:vb] = apk_lists[vb.to_s].present? ? apk_lists[vb.to_s][:size].to_i : '-'
      apklist_hash[:diff] = apklist_hash[:va].to_i - apklist_hash[:vb].to_i
      result << apklist_hash
    end

    @lists = []
    if result.present?
      #only va
      @only_va = result.select{|a| a[:vb] == '-'}.sort_by{|a| -a[:va]}
      #only vb
      @only_vb = result.select{|a| a[:va] == '-'}.sort_by{|a| -a[:vb]}
      #both va, vb
      @both = result.select{|a| a[:va] != '-' && a[:vb] != '-'}.sort_by{|a| -a[:va]}
      
      @lists = @only_va + @only_vb + @both
    end
    
    return @lists
  end

  def app_cn_name(base_cn_name, base_desktop_name)
    # 获取中文名
    if apk_cn_name.blank? || apk_cn_name == 'null'
      cn_name = base_cn_name.present? ? base_cn_name.to_s : '无'
    else
      cn_name = apk_cn_name
    end

    # 获取桌面名称
    if apk_desktop == false
      desktop_name = '无'
    else
      if apk_cn_name.blank? || apk_cn_name == 'null'
        desktop_name = base_cn_name.present? ? base_cn_name.to_s : '无'
      else
        desktop_name = apk_desktop ? apk_cn_name : '无'
      end
    end
    return {desktop_name: desktop_name, cn_name: cn_name}
  end

  def apk_has_link?
    ApkBase.find_by(name: apk_name).present?
  end
end
