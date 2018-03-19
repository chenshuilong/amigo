class IssueExportQuickerJob < IssueExportJob
  queue_as :export_quicker
end
