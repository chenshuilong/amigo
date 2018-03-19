Redmine::Plugin.register :project_risks do
  name 'Project Risks plugin'
  author 'Chengxi'
  description 'This is a plugin for Amigo to Manage project Risks'
  version '0.0.1'
  url 'http://www.gionee.com'
  author_url 'http://www.jjlam.cn'

  menu :project_menu, :risks, { :controller => 'risks', :action => 'index' }, :caption => :label_risks, :after => :files, :param => :project_id

  project_module :risks do
    permission :view_risks, :risks => :index
    permission :add_risks, :risks => [:new, :create]
  end

end
