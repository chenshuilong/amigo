module NewFeaturesHelper

  def tag_class_of(new_feature)
    %w(tag-success tag-warning tag-primary tag-info tag-complete).at(new_feature.category.to_i - 1)
  end

end
