class RepoRequestJob < ActiveJob::Base

  queue_as :repo_request # DON'T CHANGE

  def perform(repo_request_params, repo_request_id)
    repo_request = RepoRequest.find_by(id: repo_request_id)
    
    # if Rails.env.production?
    #   job_name = RepoRequest::JOB_NAME[repo_request.category]
    #   end_interval = RepoRequest::TIME_SET[:production][:end_interval]
    #   interval = RepoRequest::TIME_SET[:production][:interval]
    #   sleep_time = RepoRequest::TIME_SET[:production][:sleep]
    # else
    #   job_name = RepoRequest::JOB_NAME[4]
    #   end_interval = RepoRequest::TIME_SET[:test][:end_interval]
    #   interval = RepoRequest::TIME_SET[:test][:interval]
    #   sleep_time = RepoRequest::TIME_SET[:test][:sleep]
    # end
    # 
    job_name = RepoRequest::JOB_NAME[repo_request.category]
    end_interval = RepoRequest::TIME_SET[:production][:end_interval]
    interval = RepoRequest::TIME_SET[:production][:interval]
    sleep_time = RepoRequest::TIME_SET[:production][:sleep]
    begin
      start_time = Time.now
      end_time = Time.now + end_interval.minute
     
      @jenkins = Api::Jenkins.new
      result = @jenkins.build_branch(job_name, repo_request_params)  

      if result == "201"
        sleep 10    

        while true   

          current_number  = @jenkins.current_number(job_name)
          building  = @jenkins.current_status(job_name, current_number)  
          result = @jenkins.current_result(job_name, current_number)       

          if Time.now > end_time
            puts "DO TIMEOUT!"
            stop = @jenkins.stop_job(job_name, current_number)
            repo_request.update(status: 4) if stop == "302" && !repo_request.failed?
            break
          else
            if !building
              puts "DO #{result}!"
              if result == "SUCCESS"
                repo_request.update(status: 5) if !repo_request.successful?
              elsif %w(FAILURE ABORTED).include?(result)
                repo_request.update(status: 4) if !repo_request.failed?
              end
              break
            else
              spend = start_time + interval.minute < Time.now 
               
              if spend
                puts "DO FAILED!"
                stop = @jenkins.stop_job(job_name, current_number)
                repo_request.update(status: 4) if stop == "302" && !repo_request.failed?
                break
              else
                puts "DO NOTHING!"
                sleep sleep_time
              end
            end
          end
        end
      else
        repo_request.update(status: 4) if !repo_request.failed?
        return false
      end
    rescue => e 
      puts "Error: #{e}"
      return false
    end
  end

end
