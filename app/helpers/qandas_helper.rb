module QandasHelper


  def render_nabor_of(qanda)
    previous_html = "<span>#{l(:qanda_previous)}: </span>"
    next_html = "<span>#{l(:qanda_next)}: </span>"
    if qanda.prev.present?
      previous_html << (link_to qanda.prev.subject, qanda.prev)
    else
      previous_html << l(:label_none)
    end

    if qanda.next.present?
      next_html << (link_to qanda.next.subject, qanda.next)
    else
      next_html << l(:label_none)
    end

    content_tag :div do
      "<p class='skip pull-left'><span>#{previous_html}</span></p>
      <p class='skip pull-right'><span>#{next_html}</span></p>".html_safe
    end
  end

  def top_ten_qanda
    qandas = Qanda.top
    content_tag :ul, class: "list-unstyled" do
      qandas.map.with_index do |q, index|
        content_tag :li do
          content_tag(:span, (index + 1)) + link_to(q.subject, q, class: "ask")
        end
      end.join.html_safe
    end
  end

  def render_tag(qanda)
    tags = qanda.tag.to_s.split(",")
    if tags.present?
      content_tag :p do
        content_tag(:span, "#{l(:label_tag)}: ") +
        tags.map do |tag|
          link_to content_tag(:span, tag, :class => "tag tag-default"), qandas_path(:q => tag)
        end.join.html_safe
      end
    end
  end

end
