class AlterRecord < ActiveRecord::Base
  belongs_to :alter_for, :polymorphic => true
  belongs_to :user, :class_name => "User"
  has_many :details, :class_name => "AlterRecordDetail", :dependent => :delete_all, :inverse_of => :alter_record

  def initialize(*args)
    super
    if alter_for
      if alter_for.new_record?
        self.notify = false
      else
        start
      end
    end
  end

  def notify?
    @notify != false
  end

  def notify=(arg)
    @notify = arg
  end

  # Stores the values of the attributes
  def start
    if alter_for
      @attributes_before_change = alter_for.altered_attribute_names.inject({}) do |h, attribute|
        h[attribute] = alter_for.send(attribute)
        h
      end
    end
    self
  end

  def save(*args)
    alter_for_changes
    # Do not save an empty journal
    (details.empty? && notes.blank?) ? false : super
  end

  def css_classes
    s = 'journal'
    s << ' has-notes' unless notes.blank?
    s << ' has-details' unless details.blank?
    s
  end
  
  private
  # Generates alter record details for attribute
  def alter_for_changes
    # attributes changes
    if @attributes_before_change
      alter_for.altered_attribute_names.each {|attribute|
        before = @attributes_before_change[attribute]
        after = alter_for.send(attribute)
        next if before == after || (before.blank? && after.blank?)
        add_attribute_detail(attribute, before, after)
      }
    end
    start
  end

  # Adds a alter record detail for an attribute change
  def add_attribute_detail(attribute, old_value, value)
    property = alter_for_type == "ApkBase" ? 'update' : ''
    add_detail(property, attribute, old_value, value)
  end

  # Adds a alter record detail
  def add_detail(property, prop_key, old_value, value)
    details << AlterRecordDetail.new(:property => property, :prop_key => prop_key, :old_value => old_value, :value => value)
  end
end
