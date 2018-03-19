class Signature < ActiveRecord::Base
  belongs_to :author, :class_name => 'User'

  SIGNATURE_STATUS = {:uploading =>1, :signing => 2, :successful => 3, :failed => 4}
  SIGNATURE_CATEGORY = {:app => 1}
  SIGNATURE_KEY_NAME = %w(media platform releasekey shared testkey)
  JOB_NAME = {:job_name => "Sign_for_Application"}.freeze

  acts_as_attachable :view_permission => true,
                     :edit_permission => true,
                     :delete_permission => true

  def build_api_params
    api_params = {}
    api_params[:file_name] = name
    api_params[:key_name] = key_name
    api_params[:amige_id] = id
    return api_params
  end

  def do_jenkins_job
    job_name = JOB_NAME[:job_name]
    @jenkins = Api::Jenkins.new
    result = @jenkins.build_branch(job_name, build_api_params) 

    puts "Do_jenkins_job result: #{result}"
  end
end
