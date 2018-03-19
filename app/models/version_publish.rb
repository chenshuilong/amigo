# -*- encoding : utf-8 -*-
class VersionPublish < ActiveRecord::Base
  serialize :notes, Array

  belongs_to :version
  belongs_to :user, foreign_key:"author_id"
  belongs_to :spec

  VERSION_PUBLISH_API_PARAMS = {:app_id => "amigo", 
                                :app_key => "{}[]}sdl0opdnf,vpxp$%&!@@", 
                                :production_hostname => "idc.shop.gionee.com",
                                :other_hostname => "idc.shop.cm.com",  
                                :production_host => "10.101.0.244", 
                                :other_host => "192.168.0.86"}.freeze

  scope :index_list, lambda {
      joins("inner join specs on specs.id = version_publishes.spec_id
             inner join versions on versions.id = version_publishes.version_id
             left join projects on versions.project_id = projects.id")
      .where("published = true OR version_publishes.created_at IN (select max(created_at) from version_publishes GROUP BY spec_id)")
      .select("version_publishes.id, specs.id as spec_id,version_id,content,content_md5,published,#{table_name}.notes,publisher_id,published_on,
               versions.name as version_name,projects.name as project_name,specs.name as spec_name,projects.id as project_id, projects.identifier as project_identifier")
      .reorder("version_publishes.created_at desc")}

  def can_change?
    VersionPublish.where(spec_id: self.spec_id).order("created_at desc").first.id == self.id
  end

  def compare_and_update(new_rows, old_rows, remove_note, old_remove_note)

    return false, self unless self.can_change?

    @content = JSON.parse(self.content)
    @old_rows = old_rows
    @new_rows = new_rows
    notes = []
    edit_hash = {}
    change = false
    
    if remove_note != old_remove_note
      change = true
      edit_hash[:remove_notes] = {old: old_remove_note, new: remove_note}
    end

    if @old_rows != @new_rows
      apks = (@old_rows.keys + @new_rows.keys).uniq
      #change
      change = true
      add_array = []
      delete_array = []
      update_array = []
      apks.each do |apk|
        apk_name = apk.to_s.squish
        old_row = @old_rows[apk_name]
        new_row = @new_rows[apk_name]
        if old_row.blank? #add
          change = true
          add_array << {apk_name: apk_name, cn_name: new_row["cn_name"],desktop_name: new_row["desktop_name"], description: new_row["description"], developer: new_row["developer"],
                        apk_version: new_row["apk_version"], apk_permission: new_row["apk_permission"], apk_removable: new_row["apk_removable"]}
        elsif new_row.blank? #delete
          change = true
          delete_array << {apk_name: apk_name, cn_name: old_row["cn_name"],desktop_name: old_row["desktop_name"],description: old_row["description"],developer: old_row["developer"],
                           app_version: old_row["apk_version"], apk_permission: old_row["apk_permission"], apk_removable: old_row["apk_removable"]}
        else
          if old_row != new_row
            change = true
            update_hash = Hash.new
            update_hash[:apk_name] = apk_name
            update_hash[:cn_name] = new_row["cn_name"]
            update_hash[:old_cn_name]= old_row["cn_name"] if old_row["cn_name"] != new_row["cn_name"]
            update_hash[:old_desktop_name], update_hash[:desktop_name] = old_row["desktop_name"], new_row["desktop_name"] if old_row["desktop_name"] != new_row["desktop_name"]
            update_hash[:old_description], update_hash[:description] = old_row["description"], new_row["description"]  if old_row["description"] != new_row["description"]
            update_hash[:old_developer], update_hash[:developer] = old_row["developer"], new_row["developer"]  if old_row["developer"] != new_row["developer"]
            update_array << update_hash
          end
        end
        edit_hash[:add] = add_array if add_array.present?
        edit_hash[:delete] = delete_array if delete_array.present?
        edit_hash[:update] = update_array if update_array.present?
        change = true if edit_hash.present?
      end
    end
    notes << edit_hash
    
    if change == true
      new_content = {}
      new_content["title"] = @content["title"]
      new_content["remove_notes"] = remove_note
      new_content["rows"] = {}

      @new_rows.each do |row|
        single_row = {}
        new_content["rows"][row[0].squish] = {"cn_name"=>row[1]["cn_name"], "desktop_name"=>row[1]["desktop_name"], "description"=>row[1]["description"], 
                                              "developer"=>row[1]["developer"], "exist"=>row[1]["exist"], "missing" => row[1]["missing"]}
      end

      publish_params = {}
      publish_params["spec_id"] = self.spec_id
      publish_params["version_id"] = self.version_id
      publish_params["content"] = new_content.to_json
      publish_params["content_md5"] = Digest::MD5.hexdigest(new_content.to_json)
      publish_params["author_id"] = User.current.id
      publish_params["notes"] = notes

      @version_publish = VersionPublish.new(publish_params)
      @version_publish.save

      return true, @version_publish
    else
      return false, self
    end
  end

  def content_publish_to_security(title, name)
    @spec = spec
    @content = JSON.parse(content)

    @apk_infos = full_info_json.delete_if{|k, v| k.to_s == "remove_notes" }
    publish_info = {}
    publish_info[:project_id] = version.project_id
    publish_info[:project_external_name] = version.project.name
    publish_info[:spec_id] = spec_id
    publish_info[:version_publish_id] = id
    publish_info[:title] = name
    publish_info[:notes] = @content["remove_notes"]
    publish_info[:sorts] = title
    publish_info[:contents] = []

    @apk_infos.each do |apk|
      app_name = apk[0].squish

      single_row = {}
      single_row[:cn_name]      = apk[1][:cn_name].present? ? apk[1][:cn_name] : " "                 if title[:cn_name].present?
      single_row[:desktop_name] = apk[1][:desktop_name].present? ? apk[1][:desktop_name] : " "       if title[:desktop_name].present?
      single_row[:description]  = apk[1][:description].present? ? apk[1][:description] : " "         if title[:description].present?
      single_row[:permission]   = apk[1][:apk_permission].present? ? apk[1][:apk_permission] : " "   if title[:permission].present?
      single_row[:version_name] = apk[1][:apk_version].present? ? apk[1][:apk_version] : " "         if title[:version_name].present?
      single_row[:developer]    = apk[1][:developer].present? ? apk[1][:developer] : " "             if title[:developer].present?
      single_row[:removable]    = apk[1][:apk_removable].present? ? apk[1][:apk_removable] : " "     if title[:removable].present?
      
      publish_info[:contents] << single_row
    end

    return publish_info.to_json
  end

  def app_names(type)
  	@rows = JSON.parse(content)["rows"]
  	@rows.select{|k, v| v["type"] == type}.keys
  end

  def full_info_json
    @rows = JSON.parse(self.content)["rows"]
    @remove_notes = JSON.parse(self.content)["remove_notes"]
    @apk_infos = apk_info(@rows)
    full_infos = {}
    @rows.each do |k, v|
       full_infos[k] = {:cn_name => v["cn_name"], :desktop_name => v["desktop_name"], :description => v["description"], :developer => v["developer"], :apk_name => @apk_infos[k][:apk_name], 
                        :apk_version => @apk_infos[k][:apk_version], :apk_permission => @apk_infos[k][:apk_permission], :apk_removable => @apk_infos[k][:apk_removable], :exist => v["exist"], :missing => v["missing"]}
    end
    full_infos[:remove_notes] = @remove_notes

    return full_infos
  end

  def apk_info(rows)
    @apk_lists = version.app_lists.generate_apk_info
    @apk_infos = {}
    rows.each do |k, v|
      apk_name = k.to_s.squish
      apk = @apk_lists[apk_name]
      @apk_infos[k.to_s.squish] = {v_name: apk[:v_name], apk_name: apk_name, apk_version: apk[:app_version], apk_permission: apk[:apk_permission], apk_removable: apk[:apk_removable]}
    end

    return @apk_infos
  end

end