class GoogleTool < ActiveRecord::Base
  belongs_to :author, :class_name => 'User'
  
  serialize :tool_url, Hash

  validates :android_version, presence: :true, if: :not_gts?
  validates :tool_version, presence: :true
  validates :tool_version, uniqueness: { scope: [:category, :android_version], :message => :already_exists}

  acts_as_attachable :view_permission => true,
                     :edit_permission => true,
                     :delete_permission => true

  GOOGLE_TOOL_CATEGORY = {:cts_ctsv => 10, :vts_gsi => 20, :gts => 30}.freeze

  scope :valid_tools, lambda { where("closed_at >= '#{Time.now.strftime('%F')}' OR closed_at IS NULL").reorder("android_version desc, created_at desc")}

  def not_gts?
    !category.to_i == 30
  end

  def tool_version_text
    l("google_tool_category_#{GoogleTool::GOOGLE_TOOL_CATEGORY.key(category.to_i).to_s}")
  end

  def tool_urls
    url = {}

    get_tool_url_type.each do |item|
      url[item] = {}
      url[item]["total_count"] = 0
      url[item]["uploaded_count"] = 0
      url[item]["urls"] = []
    end

    attachments.each do |atta|
      url[atta.extra_type]["total_count"] += 1
      if atta.ftp_ip.present?
        url[atta.extra_type]["uploaded_count"] += 1
        url[atta.extra_type]["urls"] << {name: atta.disk_filename, url: File.join(Attachment::IPS[atta.ftp_ip.to_s][:ftp], "#{id}/#{atta.id}/#{atta.disk_filename}")}
      end
    end
    return url
  end

  def get_tool_url_type
    case category.to_i
    when 10
      %w(cts ctsv)
    when 20
      %w(vts gsi)
    when 30
      %w(gts)
    end
  end

  def do_delete
    @tool = self
    GoogleTool.transaction do 
      @tool.attachments.delete_all
      files = "#{Attachment::IPS['4'][:path]}/#{@tool.id}"
      FileUtils.rm_rf(files)
      @tool.destroy
    end
  end

  def update_attachments(new_files)
    attas = self.attachments
    uploaded_tokens = attas.map(&:token)
    save_files = {}
    unupload_tokens = []
    delete_tokens = []
    if new_files.present?
      get_tool_url_type.each do |item|
        if (files = new_files[item]).present?
          files.each do |k, v|
            next if v[:token].blank?
            unupload_tokens << v[:token]
            unless uploaded_tokens.include?(v[:token])
              save_files = save_files.merge([[k, v]].to_h)
            end
          end
        end
      end
    end

    delete_tokens = uploaded_tokens - unupload_tokens
    if delete_tokens.present?
      attas.each do |atta|
        if delete_tokens.include?(atta.token)
          GoogleTool.transaction do 
            files = "#{Attachment::IPS[atta.ftp_ip.to_s][:path]}/#{id}/#{atta.id}"
            FileUtils.rm_rf(files)
            atta.destroy
          end
        end
      end
    end

    return save_files
  end
end
