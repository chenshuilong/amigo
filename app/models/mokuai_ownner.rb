class MokuaiOwnner < ActiveRecord::Base

  serialize :ownner, Array

  belongs_to :project
  belongs_to :mokuai
  belongs_to :tfder, :class_name => 'User', :foreign_key => "tfde"
  belongs_to :user, :class_name => 'User', :foreign_key => "ownner"

  validates :project_id, :mokuai_id, :ownner, presence: true
  validates :project_id, uniqueness: { scope: :mokuai_id }

  def self.copy_mokuai_ownner(to, *ids)
    where(:id => ids).each do |from|
      exist_ownner = to.mokuai_ownners.find_by(:mokuai_id => from.mokuai_id)
      if exist_ownner
        exist_ownner.update_attributes(:ownner => from.ownner, :tfde => from.tfde)
      else
        to.mokuai_ownners.create(:mokuai_id => from.mokuai_id, :ownner => from.ownner, :tfde => from.tfde)
      end
    end
  end

  def main_ownner
    User.find_by(:id => self.ownner.first).name if self.ownner.present?
  end

  def minor_ownner
    self.ownner.from(1).map{|m| User.find_by(:id => m).name}.join(" / ") if self.ownner.count > 1
  end

  def omit_ownner
    name = User.find_by(:id => self.ownner.second).name if self.ownner.count > 1
    name << "等" if self.ownner.count > 2
    name
  end

end
