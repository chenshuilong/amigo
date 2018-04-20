class OkrsSupport < ActiveRecord::Base
  belongs_to :container, :polymorphic => true
  belongs_to :okrs_record
  belongs_to :okrs_object

  after_create :set_record_and_object_id

  scope :my, lambda{
    current_user = User.current
    user_ids = [current_user.id]
    if current_user.dept.present? && current_user.dept_leader.present?
      user_ids = user_ids + current_user.dept.all_users.select(:id).pluck(:id) if current_user.id == current_user.dept_leader.id
    else
      user_ids = user_ids + current_user.dept.all_users.select(:id).pluck(:id) if current_user.dept.present?
    end

    joins("left join okrs_key_results on okrs_key_results.id = okrs_supports.container_id and okrs_supports.container_type = 'OkrsKeyResult'")
    .includes(:okrs_record, :okrs_object)
    .group(:container_id)
    .where(okrs_records: {status: %w(self_scoring other_scoring)}, user_id: user_ids.uniq)
  }

  def set_record_and_object_id
    object = self.container.container
    record = object.container
    self.update_columns(okrs_record_id: record.id, okrs_object_id: object.id)
  end

  def self.delete_invalid_supports(infos)
    infos.each do |k, v|
      if v.present?
      	object = OkrsObject.find_by(uniq_key: k)
      	results = object.results
        v.each do |ki, vi|
          result = results.find_by(uniq_key: ki)
          result.supports.where(user_id: vi).delete_all
        end
      end
    end
  end
end
