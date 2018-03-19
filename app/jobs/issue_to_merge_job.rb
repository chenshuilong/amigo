class IssueToMergeJob < ActiveJob::Base

  queue_as :issue_to_merge # DON'T CHANGE

  def perform(task, build_params)
    job_name = IssueToApproveMerge::JENKINS_JOB_NAME[0]
    end_interval = RepoRequest::TIME_SET[:production][:end_interval]
    interval = RepoRequest::TIME_SET[:production][:interval]
    sleep_time = RepoRequest::TIME_SET[:production][:sleep]

    begin
      start_time = Time.now
      end_time = Time.now + end_interval.minute
     
      @jenkins = Api::Jenkins.new
      result = @jenkins.build_branch(job_name, build_params)

      if result == "201"
        sleep 10

        while true
          current_number  = @jenkins.current_number(job_name)
          building  = @jenkins.current_status(job_name, current_number)  
          result = @jenkins.current_result(job_name, current_number)       

          # stop job when current time over 25 minute else get status while unbuilding
          if Time.now > end_time
            stop = @jenkins.stop_job(job_name, current_number)
            puts "DO FAILED!" if stop == "302"
            break
          else
            if !building
              puts "DO #{result}!"

              if result == "SUCCESS"
                task.status = Task::TASK_STATUS[:merged][0]
              elsif %w(FAILURE ABORTED).include?(result)
                task.status = Task::TASK_STATUS[:unmerged][0]
              end
              update_issue_to_merge_result(task, result) if task.save
              break
            else
              spend = (start_time + interval.minute) < Time.now
               
              if spend
                stop = @jenkins.stop_job(job_name, current_number)
                puts "DO FAILED!" if stop == "302"
                break
              else
                puts "DO NOTHING!"
                sleep sleep_time
              end
            end
          end
        end
      else
        puts "DO FAILED!"
        return false
      end
    rescue => e 
      puts "Error: #{e}"
      return false
    end
  end

  private

  def update_issue_to_merge_result(task, result)
    issue_to_merge = IssueToApproveMerge.find_by_issue_type_and_id(task.container_type, task.container_id)
    repo_request_result = JSON.parse(issue_to_merge.repo_request_ids)
    repo_request_result.find { |r| r["repo_request_id"] == task.id }["merge_result"] = result
    issue_to_merge.repo_request_ids = repo_request_result.to_json
    issue_to_merge.save
  end
end
