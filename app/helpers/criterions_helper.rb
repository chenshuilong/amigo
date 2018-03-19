module CriterionsHelper

  def criterion_tabs
    tabs = [
             {:action => 'index', :path => :criterions, :label => l(:criterion_index)},
             {:action => 'report', :path => :report_criterions, :label => l(:criterion_report)},
             {:action => 'backend', :path => :backend_criterions, :label => l(:criterion_backend)}
           ]
  end

  def criterion_sidebar
    content_tag :ul, class: 'tab-group' do
      criterion_tabs.map do |tab|
        content_tag :li, class: ('active' if tab[:action] == action_name), :id => "criterion-#{tab[:action]}" do
          link_to tab[:label], tab[:path]
        end
      end.join.html_safe
    end
  end

  def render_criterion_children(criterion)
    criterion.children.map do |secondary|
      content_tag :p, "#{secondary.name}: #{secondary.target}"
    end.join.html_safe
  end

end
