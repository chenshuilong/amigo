class DefinitionSection < ActiveRecord::Base
  belongs_to :definition_custom_value
  belongs_to :definition_sections_custom_fields

  scope :unhide, -> {where(:display => true)}
  scope :main_module, -> {where(:parent_id => nil)}
  scope :second_level_module, -> {where(:parent_id => main_module.map { |m| m.id})}

  MENU_MINGMING = "命名及市场定位"
  MENU_CHANPING = "产品定义"

  def parent
    DefinitionSection.find_by(:id => self.parent_id)
  end

  def children
    DefinitionSection.where("parent in ('#{self.id}')")
  end

  def self.format_modules
    DefinitionSection.all.map { |m|
      {:id => m.id, :name => m.name, :parent_id => m.parent_id ? DefinitionSection.find(m.parent_id).name : "",
       :author_id => User.find(m.author_id).firstname, :display => m.display, :created_at => m.created_at, :updated_at => m.updated_at}
    }
  end

  def self.project_module(project_id)
    DefinitionSection.where(:id => DefinitionCustomValue.select("distinct definition_section_id").where(:definition_id => Project.find(project_id).definition.id).map{|section| section.definition_section_id})
  end
end
