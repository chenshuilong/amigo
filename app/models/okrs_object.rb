class OkrsObject < ActiveRecord::Base
  has_many :results, class_name: 'OkrsKeyResult', :as => :container, :dependent => :destroy
  has_many :supports, class_name: 'OkrsSupport', foreign_key: 'okrs_object_id'
  belongs_to :container, :polymorphic => true
end
