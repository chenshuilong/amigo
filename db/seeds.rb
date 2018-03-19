# encoding: UTF-8
# Despite the intention of seed-ing - that this is meant to be run once,
# to populate the database - there is no technical constrain preventing you from running rake db:seed command couple times.
# Even without cleaning/recreating your database.
# It's strongly recommended that you check this file into your version control system.

# ActiveRecord::Migration.new.say_with_time "Adding some test data for version_release_sdks, this may take some time..." do
#   50.times do |i|
#     begin
#       vr = VersionReleaseSdk.new({:version_id => i.succ, :status => 1, :author_id => 1, :note => "Test Data"})
#       ver = Version.find(i.succ)
#       puts "=======#{i.succ}.#{ver ? ver.fullname : 'Test Data'} was Added!=======" if vr.save
#     rescue => e
#       puts "=======Something went wrong, the reason: #{e.to_s}.======="
#       next
#     end
#   end
# end
