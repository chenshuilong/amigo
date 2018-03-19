require 'fileutils'

module GitHelper

  WROK_DIR = Rails.root.join('files/repo/gn_project')
  DEFAULT_OPTIONS = {
      # :log => Rails.logger
      :log => Logger.new(STDOUT)
  }

  USER = 'auto_rom_release'
  EMAIL = 'auto_rom_release@gionee.com'
  DEFAULT_REMOTE = 'origin'
  DEFAULT_BRANCH = 'master'

  def test
    g = Git.open('~/work/code/git/gnss', DEFAULT_OPTIONS)
    b = g.index.readable?
    puts b
  end

  # url : ssh://gerritroot@19.9.0.152:29418/android_mtk_m_6755_c66_mp/master
  # -> {
  #   :repo_uri => 'ssh://USER@19.9.0.152:29418/android_mtk_m_6755_c66_mp/gn_project',
  #   :repo_name => 'android_mtk_m_6755_c66_mp',
  #   :repo_branch => 'master'
  # }

  class << self
    def parse_url(url)
      last_slash_index = url.rindex('/')
      repo_uri = url[0 .. last_slash_index - 1] # ssh://gerritroot@19.9.0.152:29418/android_mtk_m_6755_c66_mp
      repo_name = repo_uri[repo_uri.rindex('/') + 1 .. -1] # android_mtk_m_6755_c66_mp
      schema = repo_uri[0 .. repo_uri.index('://') + 2] # ssh://
      repo_branch = url[last_slash_index + 1 .. -1] # master
      repo_path_partial = repo_uri[repo_uri.index('@') .. repo_uri.length] # @19.9.0.152:29418/android_mtk_m_6755_c66_mp
      repo_uri = File.join(schema, USER + repo_path_partial, 'gn_project') # ssh://USER@19.9.0.152:29418/android_mtk_m_6755_c66_mp/gn_project
      return {:repo_uri => repo_uri, :repo_name => repo_name, :repo_branch => repo_branch}
    end

    def clone(uri, name, branch)
      clone_dir = File.join(WROK_DIR, name, branch)
      if not Dir.exist?(clone_dir)
        g = Git.clone(uri, clone_dir, DEFAULT_OPTIONS.merge({:branch => branch}))
      else
        g = Git.open(clone_dir, DEFAULT_OPTIONS)
        g.fetch
      end
      g.config('user.name', USER)
      g.config('user.email', EMAIL)
      g
    end

    def pull_rebase(git, branch = DEFAULT_BRANCH, remote = DEFAULT_REMOTE)
      # git.lib.send(:command, 'checkout', [remote, branch])
      git.lib.send(:command, 'pull', [remote, branch, '--rebase'])
    end

    def clear(git, branch = DEFAULT_BRANCH, remote = DEFAULT_REMOTE)
      git.lib.send(:command, 'clean', [remote, branch, '-df'])
      git.lib.send(:command, 'reset --hard HEAD^^')
    end
  end
end
