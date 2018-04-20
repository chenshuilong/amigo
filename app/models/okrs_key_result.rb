class OkrsKeyResult < ActiveRecord::Base
  has_many :supports, class_name: 'OkrsSupport', :as => :container, :dependent => :destroy
  belongs_to :container, :polymorphic => true

  def save_score(score)
    @okr = self.container.container
    case @okr.status
    when "self_scoring"
    	next_status = "other_scoring"
      self.update(self_score: score)
      can_update_status =  @okr.can_change_status?
    when "other_scoring"
    	next_status = "finished"
      self.update(other_score: score)
      can_update_status =  @okr.can_change_status?
    end

    @okr.update(status: next_status) if can_update_status
    return true, can_update_status
  end
end
