require 'jenkins_api_client'
require "net/ftp"
require 'open4'

module Api
  class User
    class << self
      def where(params = {})
        url_params = {}
        url_params["usr.id"] = params[:login] if params[:login]
        url_params["usr.empId"] = params[:number] if params[:number]
        url_params["usr.usrName"] = params[:name] if params[:name]
        url_params["page"] = params[:page] if params[:page]
        url_params["status"] = params[:status] if params[:status]
        url_params["pagesize"] = params[:per_page] if params[:per_page]
        get_users(url_params.to_param)["Rows"]
      end

      def find(params = {})
        where(params).try(:first)
      end

      def count
        url_params = "page=1&pagesize=1"
        get_users(url_params)["Total"]
      end

      alias_method :find_by, :find

      private

      def get_users(params)
        current_time = Time.now.strftime('%Y%m%d%H%M%S')
        hex = Digest::MD5.hexdigest("AMG" + current_time + Object::User::KEY)
        url = "http://16.6.10.18:8088/Usr!getOrgLeaders.shtml?sc=AMG&date=#{current_time}&sec=#{hex}&#{params}"
        response = HTTParty.get url
        JSON.parse(response.body)
      end
    end
  end

  class WorkDay
    class << self
      def day(day)
        day = Date.parse(day.to_s).strftime("%F")
        check(:day => day).values.first == "true"
      end

      def month(month)
        month = (month =~ /\d{1,2}/) ? month : Date.parse(month.to_s).strftime("%m")
        check(:month => month)
      end

      def year(year)
        year = (year =~ /\d{4}/) ? year : Date.parse(year.to_s).strftime("%Y")
        check(:year => year)
      end

      def range(from, to)
        from = Date.parse(from.to_s)
        to = Date.parse(to.to_s)
        from, to = to, from if from > to
        result = {}
        from.upto(to) do |d|
          result.merge! check(:day => d.strftime("%F"))
        end
        result
      end

      private

      def check(params={})
        response = HTTParty.get "http://16.6.10.18:8088/Usr!isWorkDay.shtml?#{params.to_param}"
        rows = JSON.parse(response.body)
      end
    end
  end


  class Jenkins
    LABEL_REG = /\ABUILD_/

    def initialize
      @client = JenkinsApi::Client.new(
          :server_ip => '19.9.0.160',
          :username => 'amige',
          :password => 'OS_amigo',
          :timeout => 3,
          :http_open_timeout => 3
      )
    end

    def client
      @client
    end

    def nodes
      labels(:node => true).values.flatten.uniq
    end

    def labels(opt = {})
      result = opt[:node] ? {} : []
      nodes = client.node.list.reject { |node| node.include?('master') }
      nodes.each do |node|
        config = client.node.get_config(node)
        node_lables = Nokogiri::Slop(config).slave.label.content.try(:split, /\s/).to_a
        if opt[:node]
          node_lables.each { |label| (result[label] ||= []; result[label] << node) if LABEL_REG === label }
        else
          node_lables.each { |label| result << label if LABEL_REG === label && !result.include?(label) }
        end
      end
      result
    end

    def node_current_task(node_name)
      unless client.node.is_idle?(node_name)
        ::Version.where(:compile_start_on => Time.now.yesterday .. Time.now)
            .where("compile_status = ? AND compile_machine = ?", ::Version::VERSION_COMPILE_STATUS[:compiling], node_name)
            .order(created_on: :desc)
            .try(:first)
      end
    end

    def node_status(node_name)
      if client.node.is_offline?(node_name)
        'offline'
      elsif client.node.is_idle?(node_name)
        'idle'
      else
        'busy'
      end
    end

    def node_info(node_name, options = {})
      all = client.node.get_node_monitorData(node_name)
      config = client.node.get_config(node_name)
      nodes_hash = {
          :ip => Nokogiri::Slop(config).slave.launcher.host.content,
          :system => all["hudson.node_monitors.ArchitectureMonitor"],
          :total_memory => all["hudson.node_monitors.SwapSpaceMonitor"].try(:[], "totalPhysicalMemory").try(:to_s, :human_size),
          :available_memory => all["hudson.node_monitors.SwapSpaceMonitor"].try(:[], "availablePhysicalMemory").try(:to_s, :human_size),
          :available_disk => all["hudson.node_monitors.DiskSpaceMonitor"].try(:[], "size").try(:to_s, :human_size)
      }
      case options[:output]
        when :text
          nodes_hash.keys.map { |key| [I18n.t("repo_compile_machine_status_#{key}"), nodes_hash[key]].join(':') }.join("\n")
        when :html
          html = '<table><tbody>'
          nodes_hash.keys.each { |key| html << %(<tr><td>#{I18n.t("repo_compile_machine_status_#{key}")}</td><td>#{nodes_hash[key] || '-'}</td></tr>) }
          html << '</tbody></table>'
          html.html_safe
        else
          nodes_hash
      end
    end

    def lable_tasks_in_queue(label)
      scope = ::Version.compile_status([2, 3]).joins(:project)
      case label
        when 'BUILD_ANDROID_HOME' then
          scope = scope.where("projects.ownership = 1 AND projects.category IN (1,2,3)")
        when 'BUILD_ANDROID_OVERSEA' then
          scope = scope.where("projects.ownership = 2 AND projects.category IN (1,2,3)")
        when 'BUILD_APK' then
          scope = scope.where("projects.category  = 4")
      end
      versions = scope.uniq.reorder(priority: :asc, created_on: :asc)
    end

    def current_status(job_name, job_number)
      client.api_get_request("/job/#{URI.escape(job_name.encode(Encoding::UTF_8))}/#{job_number}")["building"]
    end

    def stop_job(job_name, job_number)
      client.job.stop_build(job_name, job_number)
    end

    def build_branch(job_name, params)
      client.job.build(job_name, params, {})
    end

    def current_result(job_name, job_number)
      client.api_get_request("/job/#{URI.escape(job_name.encode(Encoding::UTF_8))}/#{job_number}")["result"]
    end

    def current_number(job_name)
      client.job.get_current_build_number(job_name)
    end
  end

  class Version
    class << self

      def unit_test_projects
        request = HTTParty.get('http://cloud.autotest.gionee.com:8686/UserFeedback/UsersFB/qdUnitTest.json.action')
        content = JSON.parse request.body
        content["products"].split(',').map(&:strip)
      rescue
        []
      end

    end
  end

  class Smb < Sambal::Client
    DEFAULT_DIR = "/data/version_packages"

    def initialize
      @client = super(
          :domain => 'rdgionee',
          :host => '18.8.8.2',
          :share => 'software_release',
          :user => 'amige',
          :password => 'OS_amigo',
          :port => 445
      )
    end

    def download(file, dir = '')
      dest_path = dest(file, dir = '')
      finnal_dir = File.dirname dest_path
      FileUtils.mkdir_p(finnal_dir) unless File.directory?(finnal_dir)
      FileUtils.rm_rf(dest_path) if File.exist?(dest_path)
      get(file, dest_path)
    end

    def dest(file, dir = '')
      if File.extname(dir).present?
        File.join(DEFAULT_DIR, dir)
      else
        File.join(DEFAULT_DIR, dir, file)
      end
    end

  end

  class VersionPublish
    class << self

      def publish_security(content)

        api_params  = ::VersionPublish::VERSION_PUBLISH_API_PARAMS
        app_id      = api_params[:app_id]
        app_key     = api_params[:app_key]
        rnd         = rand(100000..999999)
        code        = Digest::SHA256.hexdigest(app_id + app_key + rnd.to_s)
        host        = Rails.env.production? ? api_params[:production_hostname] : api_params[:other_hostname]
        url         = "http://#{host}/api/spec.php?app_id=#{app_id}&rnd=#{rnd}&code=#{code}"

        request = HTTParty.post(url,
                               :body => content,
                               :headers => {'Content-Type' => 'application/json'})

        return request["error"].present? && request["error"] === 0
      end

    end
  end

  module Release
    USER = GitHelper::USER
    EMAIL = GitHelper::EMAIL
    PASS = 'amige123'
    DEFAULT_RELEASE_WAY = 2

    class Git
      DEFAULT_DIR = "/data/version_packages/Repository"

      attr :repository
      attr :release_way
      attr :branch
      attr :package_directory
      attr :working_directory

      def initialize(options)
        @repository, @branch, @package_directory = options[:repo].split("#")
        @release_way = options[:release_way] || DEFAULT_RELEASE_WAY
        @working_directory = File.join(
            DEFAULT_DIR,
            @repository.match(/@([\d|\.]+):\d+/)[1], # IP
            @repository.match(/:\d+\/(.+)\z/)[1].gsub("/", "__") # gn/test_project => gn__test_project
        )
        @logger = options[:logger]
      end


      def clone
        repo_url = repository.gsub(/\w+@/, "#{USER}@")
        logger.info "Check if working directory exsit"
        if Dir.exist? working_directory
          logger.info "Git open working directory: #{working_directory}"
          g = ::Git.open working_directory
          unless g.lib.branch_current == branch
            if g.branches.local.map(&:name).include?(branch) # Check if branch is arealdy exsit in local
              logger.info "Git checkout branch to: #{branch}"
              g.checkout branch
            else
              logger.info "Git checkout new branch to: #{branch}"
              g.fetch "-p" # Fetch all remote branch lits
              g.checkout branch, :b => true
            end
          end
          # Pull latest version in remote git repository
          logger.info "Update local git repo to up-to-date"
          g.fetch "--all"
          g.reset "origin/#{branch}", :hard => true
        else
          logger.info "Clone repo from: #{repo_url}"
          begin
            g = ::Git.clone(repo_url, "", :path => working_directory)
            unless g.lib.branch_current == branch # Checkout branch if needed
              logger.info "Git checkout branch to: #{branch}"
              g.checkout branch
            end
          rescue => e
            raise e.message
          end
        end
        g.config('user.name', USER)
        g.config('user.email', EMAIL)
        @git = g
      end

      def git
        @git || 'Please Clone or Open a repo first'
      end


      def dest_dir
        File.join working_directory, package_directory
      end

      def copyfiles(from, to = dest_dir)
        FileUtils.mkdir_p to unless Dir.exist?(to)
        entries = -> (dir) { Dir.entries(dir).reject { |file| %w(. ..).include? file }.join("  ") }
        if to.present?
          logger.info "Release way: #{release_way}"
          if release_way == 1
            logger.info "Replace apks and release_note"
            FileUtils.rm_rf Dir.glob("#{to}/*_Release_Note.txt") # Remove all release notes
            need_copy_files = Dir.glob("#{from}/*.apk") + Dir.glob("#{from}/*_Release_Note.txt")

            FileUtils.cp_r need_copy_files, to, :remove_destination => true
            logger.info "Copied files: #{need_copy_files.map { |file| file.split('/').last }.join('  ')}"
          else
            logger.info "Emptying folder: #{to}"
            FileUtils.rm_rf "#{to}/."

            if (deleted_files = entries.call(to)).present?
              logger.info "Deleted files: #{deleted_files}"
            else
              logger.warn "The folder is an empty folder, so nothing to clean"
            end

            logger.info "Copying files: From #{from} To #{to}"
            FileUtils.cp_r "#{from}/.", to
            logger.info "Copied files: #{entries.call(to)}"
          end
        end
      end

      def commit(message)
        if /nothing to commit/ === git.lib.send(:command, 'status')
          logger.warn "All files have no change, nothing to add/commit."
        else
          logger.info "Git add all files"
          git.add

          logger.info "Git commit, message: #{message}"
          git.commit message

          logger.info "Git push to server"
          git.push("origin", git.lib.branch_current)
        end
      end

      def logger
        @logger ||= Logger.new STDOUT
      end

    end

    class Svn
      require 'open3'

      DEFAULT_DIR = "/data/version_packages/Repository/subversion"

      attr :repository
      attr :working_directory
      attr :username
      attr :password
      attr :release_way

      def initialize(options)
        @repository = options[:repo]
        @release_way = options[:release_way] || DEFAULT_RELEASE_WAY
        @working_directory = options[:path] || DEFAULT_DIR
        @username = options[:user] || USER
        @password = options[:pass] || PASS
        @logger = options[:logger]
      end


      def clone
        FileUtils.rm_rf working_directory if Dir.exist?(working_directory)
        logger.info "Clone repo: #{repository}"
        command 'co', [repository, working_directory]
      rescue => e
        raise e.message
      end

      def status
        output = command 'status', :cd => true, :output => :stdout
        init_or_push = -> (r, k, v) { r[k].nil? ? r[k] = [v] : r[k].push(v) }
        output.split("\n").inject({}) do |result, line|
          case line
            when /\A!\s+/ then
              init_or_push.call(result, :d, $') # deleted
            when /\A\?\s+/ then
              init_or_push.call(result, :n, $') # new file
            when /\AM\s+/ then
              init_or_push.call(result, :M, $') # modified
            when /\AD\s+/ then
              init_or_push.call(result, :D, $')
            when /\AA\s+/ then
              init_or_push.call(result, :A, $')
          end
          result
        end
      end

      def add(*files)
        files = '*' if files.blank?
        logger.info "Add files: #{files}"
        command 'add', files, :cd => true
      rescue => e
        logger.warn e.message
        false
      end

      def delete(*files)
        files = status[:d] if files.blank?
        if files.present?
          logger.info "Svn delete files tracker: #{files.join("  ")}"
          command 'rm', files, :cd => true
        end
      rescue => e
        logger.warn e.message
        false
      end

      def commit(message)
        message = '"%s"' % message
        logger.info "Commit message: #{message}"
        command 'commit -m', message, :cd => true
      end

      def ls(path = repository)
        logger.info "Check remote folder if exsit: #{path}"
        command 'ls', path
      rescue => e
        logger.warn e.message
        false
      end

      def mkdir(path, message)
        message = '"%s"' % message

        arr_opts = []
        arr_opts << path
        arr_opts << "-m"
        arr_opts << message

        logger.info "Create remote dir: #{path}"
        command 'mkdir', arr_opts
      end

      def copyfiles(from, to = working_directory)

        entries = -> (dir) { Dir.entries(dir).reject { |file| %w(. .. .svn).include? file }.join("  ") }
        if to.present?
          logger.info "Release way: #{release_way}"
          if release_way == 1
            logger.info "Replace apks and release_note"
            FileUtils.rm_rf Dir.glob("#{to}/*_Release_Note.txt") # Remove all release notes
            need_copy_files = Dir.glob("#{from}/*.apk") + Dir.glob("#{from}/*_Release_Note.txt")

            FileUtils.cp_r need_copy_files, to, :remove_destination => true
            logger.info "Copied files: #{need_copy_files.map { |file| file.split('/').last }.join('  ')}"
          else
            logger.info "Emptying folder: #{to}"
            FileUtils.rm_rf Dir.glob("#{to}/*") # Important, not the same as git remove files

            if (deleted_files = entries.call(to)).present?
              logger.info "Deleted files: #{deleted_files}"
            else
              logger.warn "The folder is an empty folder, so nothing to clean"
            end

            logger.info "Copying files: From #{from} To #{to}"
            FileUtils.cp_r "#{from}/.", to
            logger.info "Copied files: #{entries.call(to)}"
          end
        end

      end

      def logger
        @logger ||= Logger.new STDOUT
      end

      private

      def auth
        "--username #{username} --password #{password}"
      end

      def command(cmd, *opts, **options)
        opts = [opts].flatten.join(' ')
        if options[:cd]
          cmd = %(cd #{working_directory} && svn #{cmd} #{opts} #{auth})
        else
          cmd = %(svn #{cmd} #{opts} #{auth})
        end
        stdin, stdout, stderr, thread = Open3.popen3 cmd
        if thread.value.success?
          options[:output] == :stdout ? stdout.read : true
        else
          raise(stderr.read)
        end
      end
    end
  end

  module ThirdpartyRelease

    class StudioCommand
      def exec_command(cmd)
        Open4::open4(cmd)
      end
    end

    class FileHelper
      # return a array
      # eg /home/www -> ["/home/www/1.text", "/home/www/2"]
      def diretory_files(dir = '', file_type = '*.*', files = nil)
        files = [] unless files
        Dir["#{dir}/*"].each { |f|

          if File.directory?(f)
            diretory_files(f, file_type, files)
          else
            files << f if file_type.to_s == '*.*' || File.extname(f).to_s.downcase == file_type.downcase
          end
        }
        files
      end
    end

    class FtpClient < Net::FTP
      DEFAULT_DIR = "files/thirdparty"

      def initialize(options = {})
        host = options[:host] || '192.168.110.95'
        username = options[:username] || '3rd'
        password = options[:password] || '8l9776rW'
        @client = super(host, username, password)
      end

      def client
        @client
      end

      def download_all_files(dir = '')
        regex = /^d[r|w|x|-]+\s+[0-9]\s+\S+\s+\S+\s+\d+\s+\w+\s+\d+\s+[\d|:]+\s(.+)/

        client.ls.each do |line|
          next if line.match(regex)
          client.get(line, File.join(DEFAULT_DIR, dir, line))
        end
      end

      def is_ftp_file?(ftp, file_name)
        ftp.chdir(file_name)
        ftp.chdir('..')
        false
      rescue
        true
      end

      def dest(file, dir = '')
        if File.extname(dir).present?
          File.join(DEFAULT_DIR, dir)
        else
          File.join(DEFAULT_DIR, dir, file)
        end
      end
    end
  end

end
