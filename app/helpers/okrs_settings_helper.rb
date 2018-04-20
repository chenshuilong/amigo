module OkrsSettingsHelper
	def cycle_options
    (1..12).to_a.collect{|a| ["每#{a}个月", a]}.push(['无', 0])
	end

	def cycle_date_options
    (1..31).to_a.collect{|a| ["#{a}号", a]}
	end
end
