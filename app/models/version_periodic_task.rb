class VersionPeriodicTask < PeriodicTask

  serialize :form_data

  VERSION_PERIODIC_TASK_STATUS = {:enable => 1, :exceptional => 3, :closed => 5}
  validate :check_version_valid

  belongs_to :author, :class_name => 'User'

  def self.permit?(user = User.current)
    user.admin? || user.groups.pluck(:lastname).include?('定期版本-项目版本负责人')
  end

  def version
    @version ||= Version.new form_data
  end

  def project
    version.project || version.spec.project
  end

  def close
    update_columns({
      :status => self.class.consts[:status][:closed],
      :closed_by_id => User.current.id,
      :closed_on => Time.now
    })
  end

  def closed_by
    User.find_by(:id => closed_by_id)
  end

  def closed?
    status == self.class.consts[:status][:closed]
  end

  def exceptional?
    status == self.class.consts[:status][:exceptional]
  end

  def build_version
    version.tap do |v|
      v.attributes = {
        :name                 => avaliable_version_name,
        :status               => ::Version.consts[:status][:planning],
        :compile_status       => ::Version.consts[:compile_status][:queued],
        :compile_due_on       => Time.now,
        :as_increase_version  => false,
        :description          => "本版本由周期版本任务：#{name} 自动生成",
        :author_id            => author_id,
        :continue_integration => form_data[:continue_integration] || false
      }
    end
  end

  def avaliable_version_name
    rule_range = version.rule.range
    if rule_range.present?
      # project.generate_version_name(nil, rule_range)
      project.generate_version_name(project.android_platform.to_i == 2 ? version.spec.id : nil, rule_range)
    else
      project.default_version_name
    end
  end

  class Version < ::Version
    attr_accessor :rule_id
    def rule; VersionNameRule.find_by(:id => rule_id) end
  end

  private

  def check_version_valid
    version.valid?
    if version.errors.messages.except(:name).present?
      errors.add :version, l(:notice_required_field)
    end
  end

end
