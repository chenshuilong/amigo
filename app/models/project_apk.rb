class ProjectApk < ActiveRecord::Base
  belongs_to :project
  belongs_to :apk_base
end
