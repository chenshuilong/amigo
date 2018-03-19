class GradleCategory < Enumeration
  OptionName = :enumeration_gradle_categories

  def option_name
    OptionName
  end

  def self.default
    d = super
    d = first if d.nil?
    d
  end
end
