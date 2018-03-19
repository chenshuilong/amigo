module DefaultValuesHelper

  def mokuai_options(value)
    hash = JSON.parse value
    project = Project.find_by(:id => hash["issue[project_id]"].to_i)
    project ||= Project.find_by(:identifier => hash["issue[project_identifier]"].to_s)
    reason = hash["issue[mokuai_reason]"]
    # reason = project.mokuai_reasons.first if project.mokuai_reasons.exclude?(reason)
    project.mokuais(reason)
  end

  def mokuai_reasons(value)
    hash = JSON.parse value
    project = Project.find_by(:id => hash["issue[project_id]"].to_i)
    project ||= Project.find_by(:identifier => hash["issue[project_identifier]"].to_s)
    project.mokuai_reasons
  end

  def tracker_options(value)
    hash = JSON.parse value
    project = Project.find_by(:id => hash["issue[project_id]"].to_i)
    project ||= Project.find_by(:identifier => hash["issue[project_identifier]"].to_s)
    project.trackers.pluck(:id, :name)
  end

  def pinzhi_options(value)
    hash = JSON.parse value
    xx = hash["issue[custom_field_values][#{IssueCustomField.xianxiang.try(:id)}]"] || Mokuai.xianxiang.first.try(:reason) || 'cenx'
    pzs =  Mokuai.xianxiang.where(:reason => xx).pluck(:name, :description)
    { relation: pzs.to_h, names: pzs.map(&:first) }.to_json
  end

  def user_filed(value)
    values = []
    hash = JSON.parse value
    # Assigned_to
    assigned_to = hash["issue[assigned_to_id]"]
    if assigned_to.present?
      values.push(
        {
          :id => "#issue_assigned_to_id",
          :text => User.find(assigned_to).name,
          :value => assigned_to
        }
      )
    end
    # TFDE
    tfde = hash["issue[tfde_id]"]
    if tfde.present?
      values.push(
        {
          :id => "#issue_tfde_id",
          :text => User.find(tfde).name,
          :value => tfde
        }
      )
    end
    # CustomField user
    cf_users_id = CustomField.where(field_format: 'user').pluck(:id)
    cf_users_id.each do |id|
      cf = hash["issue[custom_field_values][#{id}]"]
      if cf.present?
        values.push(
          {
            :id => "#issue_custom_field_values_#{id}",
            :text => User.find(cf).name,
            :value => cf
          }
        )
      end
    end
    values.to_json
  end

  def mail_receivers(value)
    hash = JSON.parse value
    mrs = hash["version[mail_receivers][]"]
    User.where(:id => mrs).map do |user|
      {:text => user.name, :id => user.id}
    end.to_json
  end


end
