module ApiHelper

  def status_history(issue)
    histories = JournalDetail.select("journals.user_id, users.firstname, journals.created_on, o_s.name as old_status_name, s.name as status_name")
                             .joins(journal: [:issue, :user])
                             .joins("inner join issue_statuses as o_s on old_value = o_s.id inner join issue_statuses as s on value = s.id")
                             .where("prop_key = 'status_id' AND issues.id = ?", issue.id)
                             .order("journals.created_on ASC")
    if histories.blank?
      [{:created_on => format_time(issue.created_on), :status_name => issue.status.name, :user_name => issue.author.name}]
    else
      hash = [{:created_on => format_time(issue.created_on), :status_name => histories.first.old_status_name, :user_name => issue.author.name}]
      histories.each do |h|
        hash << {:created_on => format_time(h.created_on), :status_name => h.status_name, :user_name => h.firstname}
      end
      hash
    end
  end

  def status_and_assigned_history(issue)
    query = <<~MYSQL
      SELECT a.id, a.created_on, a.user_id author_id, users.firstname author_name,
      b.old_value old_assigned_id, old_user.firstname old_assigned_name, b.value assigned_id, cur_user.firstname assigned_name,
      c.old_value old_status_id, old_stus.name old_status_name, c.value `status_id`, cur_stus.name `status_name`  FROM journals a
      LEFT JOIN journal_details b ON a.id=b.journal_id AND b.prop_key='assigned_to_id'
      LEFT JOIN journal_details c ON a.id=c.journal_id AND c.prop_key='status_id'
      LEFT JOIN users ON users.id = a.user_id
      LEFT JOIN users old_user ON old_user.id = b.old_value AND b.prop_key='assigned_to_id'
      LEFT JOIN users cur_user ON cur_user.id = b.value AND b.prop_key='assigned_to_id'
      LEFT JOIN issue_statuses old_stus ON old_stus.id = c.old_value AND c.prop_key='status_id'
      LEFT JOIN issue_statuses cur_stus ON cur_stus.id = c.value AND c.prop_key='status_id'
      WHERE journalized_id = #{issue.id} AND (b.prop_key IS NOT NULL OR c.prop_key IS NOT NULL)
      ORDER BY created_on
    MYSQL
    histories = Journal.find_by_sql(query)
    if histories.blank?
      [{:created_on => format_time(issue.created_on), :status_name => issue.status.name, :assigned_name => issue.assigned_to.try(:name), :user_name => issue.author.name}]
    else
      old_status = histories.detect{|h| h.old_status_name.present?}.try(:old_status_name) || issue.status.name
      old_assigned = if first_assigned_record = histories.detect{|h| h.assigned_name.present?}
        first_assigned_record.try(:old_assigned_name)
      else
        issue.assigned_to.try(:name)
      end
      hash = [{:created_on => format_time(issue.created_on), :status_name => old_status, :assigned_name => old_assigned, :user_name => issue.author.name}]
      histories.each do |h|
        old_status = h.status_name if h.status_name.present?
        old_assigned = h.assigned_name if h.assigned_name.present?
        hash << {:created_on => format_time(h.created_on), :status_name => old_status, :assigned_name => old_assigned, :user_name => h.author_name}
      end
      hash
    end
  end

end
