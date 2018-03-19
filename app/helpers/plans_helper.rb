module PlansHelper
  include SpecsHelper

  def allow_to_view_plan?
    User.current.allowed_to?(:view_plans, @project, :global => true) || User.current.admin?
  end

  def allow_to_edit_plan?
    User.current.allowed_to?(:edit_plans, @project, :global => true) || User.current.admin?
  end

  def display_seetings
    content_tag :p, "显示设定（各节点显示时间方式有如下三种，时间区间表示计划开始和结束时间区间段）："
  end

  def branches
    @lines.collect { |line, points| {line => points.group_by(&:line_name)} }
  end

  def branch_children(points)
    parent_children = []
    points.each { |point| child_points(point.id).group_by(&:group_key).each { |key, children| parent_children << [point.id, children] } }
    parent_children
  end

  def child_points(related_id)
    @project.timelines.select("timelines.related_id,timelines.name line_name,plans.name plan_name,timelines.parent_id,timelines.group_key,
          case when timelines.time_display = 1 then plans.plan_start_date
               when timelines.time_display = 2 then plans.plan_due_date
               when timelines.time_display = 3 then plans.created_at end plan_date").joins("inner join plans on plans.id = timelines.related_id").where(:parent_id => related_id)
  end

  def test_plan_timelines
    [
        { :id => 1, :container_id => 1, :containerr_type => "Plan", :group_key => "group1", :related_id => nil, :parent_id => nil, :enable => true, :author_id => 1 },
        { :id => 2, :container_id => 2, :containerr_type => "Plan", :group_key => "group1", :related_id => nil, :parent_id => nil, :enable => true, :author_id => 1 },
        { :id => 3, :container_id => 3, :containerr_type => "Plan", :group_key => "group1", :related_id => nil, :parent_id => nil, :enable => true, :author_id => 1 },
        { :id => 4, :container_id => 4, :containerr_type => "Plan", :group_key => "group1", :related_id => nil, :parent_id => nil, :enable => true, :author_id => 1 },
        { :id => 5, :container_id => 5, :containerr_type => "Plan", :group_key => "group1", :related_id => nil, :parent_id => nil, :enable => true, :author_id => 1 },
        { :id => 6, :container_id => 6, :containerr_type => "Plan", :group_key => "group1", :related_id => nil, :parent_id => nil, :enable => true, :author_id => 1 },
        { :id => 7, :container_id => 7, :containerr_type => "Plan", :group_key => "group1", :related_id => nil, :parent_id => nil, :enable => true, :author_id => 1 },
        { :id => 8, :container_id => 8, :containerr_type => "Plan", :group_key => "group1", :related_id => nil, :parent_id => 2, :enable => true, :author_id => 1 },
        { :id => 9, :container_id => 9, :containerr_type => "Plan", :group_key => "group1", :related_id => nil, :parent_id => 2, :enable => true, :author_id => 1 },
        { :id => 10, :container_id => 10, :containerr_type => "Plan", :group_key => "group1", :related_id => nil, :parent_id => 2, :enable => true, :author_id => 1 },
        { :id => 11, :container_id => 11, :containerr_type => "Plan", :group_key => "group1", :related_id => nil, :parent_id => 2, :enable => true, :author_id => 1 },
        { :id => 12, :container_id => 12, :containerr_type => "Plan", :group_key => "group1", :related_id => nil, :parent_id => 2, :enable => true, :author_id => 1 },
        { :id => 13, :container_id => 13, :containerr_type => "Plan", :group_key => "group1", :related_id => nil, :parent_id => 2, :enable => true, :author_id => 1 }
    ]
  end

  # draw timeline by paramter plans
  # paramter plans group by parent_id
  def draw_timeline(plans)
    timeline_root     = plans.find_all { |plan| plan[:parent_id].nil? }
    timeline_children = plans - [timeline_root]

    main_timeline     = draw_renderer << draw_line(0, 100, 2000, 100)
    timeline_root.each_with_index do |timeline, idx|
      main_timeline << draw_text(Plan.find(timeline.container_id).name, 0, 100 - 20)
      main_timeline << draw_active_point((idx + 50) * 100, 100) if timeline.enable
      main_timeline << draw_die_point((idx + 50) * 100, 100) if !timeline.enable
      main_timeline << draw_text(Plan.find(timeline.container_id).plan_start_date.gsub('-', '.'), 0, 200 + 20)
    end

    timeline_children.each_with_index do |timeline, idx|
      main_timeline << draw_text(Plan.find(timeline.container_id).name, 0, 200 - 20)
      main_timeline << draw_active_point((idx + 50) * 100, 200) if timeline.enable
      main_timeline << draw_die_point((idx + 50) * 100, 200) if !timeline.enable
      main_timeline << draw_text(Plan.find(timeline.container_id).plan_start_date.gsub('-', '.'), 0, 200 + 20)
    end
    main_timeline << draw_refresh
    javascript_tag("#{main_timeline}")
  end

  def draw_init(document_id)
    "$('##{document_id}').jqxDraw({renderEngine: 'HTML5'});
     var renderer = $('##{document_id}').jqxDraw('getInstance');"
  end

  def draw_line(x1, y1, x2, y2)
    "renderer.line(#{x1}, #{y1}, #{x2}, #{y2}, { stroke: '#EAEAEA', 'stroke-width': 5 });"
  end

  def draw_active_point(cx, cy)
    "renderer.attr(renderer.circle(#{cx}, #{cy}, 8, {}), { fill: 'lightyellow' });
     renderer.attr(renderer.circle(#{cx}, #{cy}, 4, {}), { fill: '#f88829' });"
  end

  def draw_die_point(cx,  cy)
    "renderer.attr(renderer.circle(#{cx}, #{cy}, 5, {}), { fill: '#EAEAEA' });"
  end

  def draw_text(content, x, y)
    "renderer.text('#{content}', #{x}, #{y}, undefined, undefined, 0, { 'class': 'smallText' }, false, 'center', 'center', 'centermiddle');"
  end

  def draw_refresh
    "renderer.refresh();"
  end

  def sortable_js(document_id)
    sortable = "$('##{document_id}').jqxSortable({ connectWith: '.sortable', opacity: 0.5});"
    sortable << "$('##{document_id}').on('stop', function (e) {var lines = [];$('##{document_id}').find('table').each(function(index,item){
      lines.push($(item).find('tr:first td:first')[0].innerText);});console.log(lines);});"

    javascript_tag sortable
  end

  def import
    Project.where("id <> 6 and category <> 4").each do |project|
      Project.find(6).plans.where(:parent_id => nil).each do |plan|
        project.plans << Plan.new({:name => plan.name, :lft => plan.lft, :rgt => plan.rgt, :parent_id => nil}) if project.plans.find_by_name(plan.name).blank?
      end
    end

    Project.where("id <> 6 and category <> 4").each do |project|
      Project.find(6).plans.where("parent_id is not null").each do |plan|
        parent_id = project.plans.find_by_name(Plan.find(plan.parent_id).name).id
        project.plans << Plan.new({:name => plan.name, :lft => plan.lft, :rgt => plan.rgt, :parent_id => parent_id}) if project.plans.find_by_name(plan.name).blank?
      end
    end
  end
end
