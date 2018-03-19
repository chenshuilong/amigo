class TestJob < ActiveJob::Base
  queue_as :release

  # This job is just for test when you need
  # You can change the perform conent as you wish

  def perform(level)

    # case level
    # when 'long'
    #   sleep 60
    #   puts "I was slept 60s"
    # when 'short'
    #   sleep 30
    #   puts "I was slept 30s"
    # when 'right_now'
    #   slepp 10
    #   puts "I was slept 10s"
    # else
    #   sleep 1
    #   puts "I was slept 1s"
    # end

    puts Time.now
    a = Thread.new do
      puts "I am T-1"
      sleep 5
      puts "I am T-1 END"
      sleep 5
      puts "I am T-1 END AND END"
    end

    b = Thread.new do
      puts "I am T-2"
      sleep 2
      puts "I am T-2 END"
    end

    a.join
    b.join

    puts "GOOD, NICE JOB!"

  end
end
