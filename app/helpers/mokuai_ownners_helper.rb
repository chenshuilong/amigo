module MokuaiOwnnersHelper

  # mo is mokuai owner
  def omit_options_for_mokuai_owner(mo, cate, default)
    case cate
      when :tfde
        user = User.where(:id => mo.tfde)
      when :main_ownner
        user = User.where(:id => mo.ownner.first)
      when :minor_ownner
        user = User.where(:id => mo.ownner.from(1))
    end
    options_from_collection_for_select(user, :id, :name, default)
  end

end
