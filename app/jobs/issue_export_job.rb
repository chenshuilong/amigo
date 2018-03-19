class IssueExportJob < ActiveJob::Base
  include QueriesHelper

  queue_as :export

  # rescue_from(ErrorLoadingSite) do
  #   retry_job wait: 1.minutes, queue: :low_priority
  # end

  def perform(id)
    export = Export.find id
    return true if export.deleted?

    begin # catch error
      export.quick
    rescue => e
      puts "Error occured, Export id: #{id}, #{e}"
      export.update_column :status, Export::EXPORT_STATUS[:failed]
    end
  end
end



