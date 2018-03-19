# encoding: utf-8
#
# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

module MyHelper
  def calendar_items(startdt, enddt)
    Issue.visible.
      where(:project_id => User.current.projects.map(&:id)).
      where("(start_date>=? and start_date<=?) or (due_date>=? and due_date<=?)", startdt, enddt, startdt, enddt).
      includes(:project, :tracker, :priority, :assigned_to).
      references(:project, :tracker, :priority, :assigned_to).
      to_a
  end

  def documents_items
    Document.visible.order("#{Document.table_name}.created_on DESC").limit(10).to_a
  end

  def issuesassignedtome_items
    Issue.visible.open.
      assigned_to(User.current).
      limit(10).
      includes(:status, :project, :tracker, :priority).
      references(:status, :project, :tracker, :priority).
      order("#{IssuePriority.table_name}.position DESC, #{Issue.table_name}.updated_on DESC")
  end

  def issuesreportedbyme_items
    Issue.visible.
      where(:author_id => User.current.id).
      limit(10).
      includes(:status, :project, :tracker).
      references(:status, :project, :tracker).
      order("#{Issue.table_name}.updated_on DESC")
  end

  def issueswatched_items
    Issue.visible.open.on_active_project.watched_by(User.current.id).recently_updated.limit(10)
  end

  def news_items
    News.visible.
      where(:project_id => User.current.projects.map(&:id)).
      limit(10).
      includes(:project, :author).
      references(:project, :author).
      order("#{News.table_name}.created_on DESC").
      to_a
  end

  def timelog_items
    TimeEntry.
      where("#{TimeEntry.table_name}.user_id = ? AND #{TimeEntry.table_name}.spent_on BETWEEN ? AND ?", User.current.id, User.current.today - 6, User.current.today).
      joins(:activity, :project).
      references(:issue => [:tracker, :status]).
      includes(:issue => [:tracker, :status]).
      order("#{TimeEntry.table_name}.spent_on DESC, #{Project.table_name}.name ASC, #{Tracker.table_name}.position ASC, #{Issue.table_name}.id ASC").
      to_a
  end

  def company_links
    [
      {
        :name => "HR",
        :contents => [
          {:title => "金立办公与自动化系统", :subtitle => "办公考勤", :description => "使用工号登录", :url => "http://hr.gionee.com/", :image => "1"},
          {:title => "金立办公与自动化补单系统", :subtitle => "补单", :description => "使用工号登录", :url => "http://16.6.10.18:8088/", :image => "2"},
          {:title => "金立工作流平台", :subtitle => "流程会签系统", :description => "使用工号登录", :url => "http://flow.gionee.com/index.html",:image => "3"},
          {:title => "对比机系统", :subtitle => "对比机申请、查询", :description => "使用工号登录", :url => "http://ppmm.gionee.com/", :image => "4"},
          {:title => "借机管理", :subtitle => "样机管理", :description => "使用工号登录", :url => "http://bos.gionee.com/", :image => "5"}
        ]
      },
      {
        :name => "软件管理",
        :contents => [
          {:title => "平台gerrit", :subtitle => "代码管理", :description => "需发邮件给scm_team@gionee.com开通账号", :url => "http://19.9.0.151/", :image => "6"},
          {:title => "APKgerrit", :subtitle => "代码管理", :description => "需发邮件给scm_team@gionee.com开通账号", :url => "http://19.9.0.146:8081/", :image => "7"},
          {:title => "SVN代码库", :subtitle => "代码管理", :description => "需发邮件给scm_team@gionee.com开通账号", :url => "http://192.168.110.97/svn/", :image => "8"},
          {:title => "Build Robot", :subtitle => "编译管理", :description => "需发邮件给scm_team@gionee.com开通账号", :url => "http://19.9.0.148/", :image => "9"},
          {:title => "版本FTP服务器", :subtitle => "版本存放", :description => "需发邮件给scm_team@gionee.com开通账号", :url => "ftp://18.8.8.2/software_release/", :image => "10"},
          {:title => "项目信息", :subtitle => "项目信息查询", :description => "账号：pm_ro\n密码：sNT8Dk6P", :url => "ftp://192.168.110.95/", :image => "11"},
          {:title => "北研Redmine系统", :subtitle => "北研项目管理", :description => "需找刘小惠开通账号", :url => "http://by.gionee.com", :image => "12"},
          {:title => "CQ网页版", :subtitle => "CQ在线BUG管理", :description => "需发邮件给scm_team@gionee.com开通账号", :url => "http://192.168.110.91:8080/cqweb/login", :image => "13"},
          {:title => "Mediatek Eservice", :subtitle => "给MTK提eservice入口", :description => "可找部门经理咨询账号和密码", :url => "http://eservice.mediatek.com/", :image => "14"},
          {:title => "Sonar", :subtitle => "代码质量检测", :description => "需发邮件给scm_team@gionee.com开通账号", :url => "http://19.9.0.104:9000/sonar/", :image => "15"},
          {:title => "禅道", :subtitle => "第三产品中心项目缺陷管理", :description => "游戏大厅单独开通账号", :url => "https://amigame.5upm.com/my/", :image => "16"},
          {:title => "专利管理", :subtitle => "专利提交及状态查询", :description => "需找王敏生申请账号", :url => "http://ipr.gionee.com/", :image => "17"},
          {:title => "高通", :subtitle => "高通官网", :description => "请向部门经理咨询账号和密码", :url => "https://createpoint.qti.qualcomm.com", :image => "8"}
        ]
      },
      {
        :name => "技术资料",
        :contents => [
          {:title => "架构文档", :subtitle => "技术资料", :description => "需发邮件给scm_team@gionee.com开通账号", :url => "http://192.168.110.97/svn/Documents/AmigoDesign/", :image => "18"},
          {:title => "历史驱动设计文档", :subtitle => "可供参考的一些历史驱动的设计文档", :description => "需发邮件给scm_team@gionee.com开通账号", :url => "http://192.168.110.97/svn/Advanced_Documents/", :image => "19"},
          {:title => "流程文档", :subtitle => "OS中心所有流程文档查阅", :description => "用户名和密码为各自邮箱前缀，需找郭占华开通账号", :url => "http://192.168.0.14/svn/Project_process/", :image => "20"},
          {:title => "Framework内部分析文档", :subtitle => "内部同学撰写的分析文档", :description => "需发邮件给scm_team@gionee.com开通账号", :url => "http://192.168.110.97/svn/Documents/AndroidFrameworkAnalysis/", :image => "21"},
          {:title => "IT Support", :subtitle => "常用办公软件及帮助文档", :description => "直接内网登陆使用", :url => "http://it.gionee.com/", :image => "22"}
        ]
      },
      {
        :name => "用户管理",
        :contents => [
          {:title => "金立反馈管理系统", :subtitle => "金立信息反馈入口", :description => "需找张妮申请账号", :url => "https://insight.gionee.com:2443", :image => "23"},
          {:title => "金立售后反馈系统", :subtitle => "金立售后查询处理入口", :description => "需找张妮申请账号", :url => "https://telemgr.gionee.com:2445/telepath", :image => "24"},
          {:title => "BI", :subtitle => "应用运营数据、用户分析", :description => "需找史伟国申请账号", :url => "http://bi.gionee.com/", :image => "28"}
        ]
      },
      {
        :name => "测试管理",
        :contents => [
          {:title => "自动化云平台", :subtitle => "自动化测试管理平台", :description => "账号请使用公司邮箱自行注册", :url => "http://cloud.autotest.gionee.com:8686/DataAnalysis/", :image => "25"},
          {:title => "SPMS", :subtitle => "服务器测试管理系统", :description => "账号请使用公司邮箱自行注册", :url => "http://42.121.88.33:5000/auth/login?next=%2Fmanage%2Fprojects", :image => "26"},
          {:title => "STM", :subtitle => "软件测试管理平台", :description => "账号找测试主管或测试经理申请", :url => "http://stm.gionee.com", :image => "27"}
        ]
      }
    ]
  end

  def get_dept_json(depts)
    depts.active.map do |dept|
      has_children = dept.children.active.present?
      {
        :id => "dept_#{dept.id}",
        :text => dept.orgNm,
        :isFolder => has_children,
        :isLazy => has_children
      }
    end
  end

  def get_user_json(users, page = 1)
    limit = 25
    page = page.to_i == 0 ? 1 : page.to_i
    offset = (page - 1) * limit
    users.order(:status).offset(offset).limit(limit).map do |user|
      {
        :id         => user.id,
        :name       => user.firstname,
        :mail       => user.mail,
        :phone      => user.phone,
        :mobile     => user.mobile,
        :dept       => user.dept_name,
        :qq         => user.qq,
        :number     => user.empId,
        :status     => user.status,
        :picture    => user.picture.normal.url,
        :avatar     => user.picture.large.url
      }
    end.compact
  end

  def tasks_menu_list
    @notices = User.current.notices
    [{
        "id" => "100", "text" => "项目计划任务", "tooltip" => "项目计划任务", "isFolder" => true, "isExpanded" => true,
        "children" => [
          {
            "id" => "100_100",
            "text" => "我的未完成任务",
            "href" => "/my/tasks?type=plan_task&status=1,2,3,4,5,7",
            "tooltip" => "未完成的项目计划任务"
          },
          {
             "id" => "100_101",
             "text" => "我的已完成任务",
             "href" => "/my/tasks?type=plan_task&status=6",
             "tooltip" => "已完成的项目计划任务"
          },
          {
              "id" => "100_102",
              "text" => "我分配的未完成任务",
              "href" => "#",
              "tooltip" => "我分配的未完成任务"
          },
          {
              "id" => "100_103",
              "text" => "我分配的已完成任务",
              "href" => "#",
              "tooltip" => "我分配的已完成任务"
          }
        ]
    },{
        "id" => "200", "text" => "项目问题任务", "tooltip" => "项目必合问题任务", "isFolder" => true, "isExpanded" => true,
        "children" => [
            {
                "id" => "200_100",
                "text" => "我的必合问题任务 #{@notices[:items][:issue_to_approve].present? ? content_tag(:span, @notices[:items][:issue_to_approve][:count], class: 'badge').html_safe : ''}",
                "href" => "/my/tasks?type=issue_to_approve_task",
                "tooltip" => "我的必合问题任务"
            },
            {
                "id" => "200_101",
                "text" => "我的合入问题任务 #{@notices[:items][:issue_to_merge].present? ? content_tag(:span, @notices[:items][:issue_to_merge][:count], class: 'badge').html_safe : ''}",
                "href" => "/my/tasks?type=issue_to_merge_task",
                "tooltip" => "我的合入问题任务"
            },
            {
                "id" => "200_102",
                "text" => "我的专项测试任务 #{@notices[:items][:issue_to_special_test_result].present? ? content_tag(:span, @notices[:items][:issue_to_special_test_result][:count], class: 'badge').html_safe : ''}",
                "href" => "/my/tasks?type=issue_to_special_test_task",
                "tooltip" => "我的专项测试任务"
            }
        ]
    },{
        "id" => "300", "text" => "个人任务", "tooltip" => "个人任务", "isFolder" => true, "isExpanded" => true,
        "children" => [
            {
                "id" => "300_100",
                "text" => "个人分配的任务",
                "href" => "/my/tasks?type=personal_task&person_type=author_id",
                "tooltip" => "个人分配的任务"
            },
            {
                "id" => "300_101",
                "text" => "个人接收的任务 #{@notices[:items][:personal_task].present? ? content_tag(:span, @notices[:items][:personal_task][:count], class: 'badge').html_safe : ''}",
                "href" => "/my/tasks?type=personal_task&person_type=assigned_to_id",
                "tooltip" => "个人接收的任务"
            }
        ]
    },{
        "id" => "400", "text" => "Patch合入任务", "tooltip" => "Patch合入任务", "isFolder" => true, "isExpanded" => true,
        "children" => [
            {
                "id" => "400_100",
                "text" => "版本验证任务 #{@notices[:items][:patch_version].present? ? content_tag(:span, @notices[:items][:patch_version][:count], class: 'badge').html_safe : ''}",
                "href" => "/my/tasks?type=patch_version_task",
                "tooltip" => "版本验证任务"
            },
            {
                "id" => "400_101",
                "text" => "分支升级任务 #{@notices[:items][:library_update].present? ? content_tag(:span, @notices[:items][:library_update][:count], class: 'badge').html_safe : ''}",
                "href" => "/my/tasks?type=library_update_task",
                "tooltip" => "分支升级任务"
            },
            {
                "id" => "400_102",
                "text" => "合入推送任务 #{@notices[:items][:library_merge].present? ? content_tag(:span, @notices[:items][:library_merge][:count], class: 'badge').html_safe : ''}",
                "href" => "/my/tasks?type=library_merge_task",
                "tooltip" => "合入推送任务"
            }
        ]
    },{
        "id" => "500", "text" => "APK信息评审", "tooltip" => "APK信息评审", "isFolder" => true, "isExpanded" => true,
        "children" => [
            {
                "id" => "500_100",
                "text" => "APK信息评审 #{@notices[:items][:apk_base].present? ? content_tag(:span, @notices[:items][:apk_base][:count], class: 'badge').html_safe : ''}",
                "href" => "/my/tasks?type=apk_base_task",
                "tooltip" => "APK信息评审"
            }
        ]
    }]
  end
end
