# Chengxi's Coffeescripts
# Amigo Project Management System
# From 2017/01/22

# Declare _GlobleMethods
`_globalMethods = {}`


$(document).ready ->

  ## Baidu analyze
  _hmt = _hmt or []
  do ->
    hm = document.createElement('script')
    hm.src = 'https://hm.baidu.com/hm.js?0354c12fc45a65e44768dd3784956227'
    s = document.getElementsByTagName('script')[0]
    s.parentNode.insertBefore hm, s
    return

  ## Output console info
  do ->
    e = undefined
    if window.console and 'undefined' != typeof console.log
      try
        (window.parent.__has_console_security_message or window.top.__has_console_security_message) and (e = !0)
      catch o
        e = !0
      if window.__has_console_security_message or e
        return

      s = '\u4E00\u4E2A\u7AD9\u5728\u5DE8\u4EBA\u80A9\u4E0A\u7684\u4FE1\u606F\u7CFB\u7EDF'
      n = ['protocol', 'host'].map((m) -> window.location[m]).join('//')
      i = [s, ' ', n].join('')

      if /msie/gi.test(navigator.userAgent) then console.log(i) else console.log('%c \u963F\u7C73\u54E5 %c Copyright © 2016-%s', 'font-family: "Helvetica Neue", "Microsoft Yahei", Helvetica, Arial, sans-serif;font-size:64px;color:#f88829;-webkit-text-fill-color:#f88829;-webkit-text-stroke: 1px #f88829;', 'font-size:12px;color:#999999;', (new Date).getFullYear())
      console.log('\n ' + i)
      window.__has_console_security_message = !0

  # Link hijack
  $(document.body).on 'click', 'div.wiki a, div.note-content a', (event) ->
    shenzhenIP = "19.9.0.162"
    if new RegExp(shenzhenIP.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&')).test @href
      event.preventDefault()
      # window.open("http://#{shenzhenIP}:8000/?url=#{encodeURIComponent @href}", '_blank')
      window.open("/ftp_log?url=#{encodeURIComponent @href}", '_blank')
      return false

  ## Version Release
  # Show different category content for VersionRelease
  $('#all_attributes').on 'change', '#version_release_category', ->
    $.ajax
      url: '/version_releases/new'
      type: 'post'
      data: $(this).closest('form').serialize()
    return

  # Three linkpage of Version Release selecting app version
  $('.version-release-form').on 'change', '#version_release_project_id, #version_release_spec_id, #version_release_version_id', ->
    $dom =
      category     : $('#version_release_category'),
      project      : $('#version_release_project_id'),
      spec         : $('#version_release_spec_id'),
      version      : $('#version_release_version_id'),
      tested_mobile: $('#version_release_tested_mobile')
      adapt_notice : $('#adapt-notice')
    data =
      category: $dom.category.val()
      project_id: $dom.project.val()
      spec_id: $dom.spec.val() if this == $dom.spec[0]
      version_id: $dom.version.val() if this == $dom.version[0]

    return if !data.project_id
    $.get '/version_releases/version_lists', data, (result) ->
      $.each result, (key, value) ->
        # console.log key, JSON.stringify value
        $obj = $($dom[key])
        if value? && $.isArray(value)
          $obj.children().remove()
          for item in value
            $obj.append "<option value=#{item.id}>#{item.name}</option>"
          $obj.find('option').prop('selected', true) if data.category == "3" && key == 'tested_mobile'
          $obj.trigger('select2.change')
        else # Do notice adapt release if need
          return if $obj.length <= 0 || key != 'adapt_notice'
          if value?
            $obj.html "<span class='flash success'><a target='_blank' href='/version_releases/#{value.id}'>查看封版信息</a></span>"
          else
            $obj.html "<span class='flash warning'>
                         <span class='text-danger'>该版本尚未封版，如果未与SPM达成一致，本次发布可能会被拒绝</span><br/>
                         <input type='checkbox' name='acceptAdaptNotice'/><span>我已经知晓</span>
                       </span>"
      return

  ## Issue
  $("#issue-form").on 'change', 'input#issue_custom_field_values_5', ->
    data = { xx_name: $(this).val() }
    $.get '/api/xianxiang', data, (result) ->
      $('#issue_custom_field_values_17')
        .data('relation', result.relation)
        .select2({data: result.names}).trigger('change.select2')
      return

  $("#issue-form").on 'change', 'input#issue_custom_field_values_17', ->
    # return unless window.location.href.match(/\/(new|copy)$/) # Releated when new issue
    _this = this
    if !$(@).data('relation')
      $("input#issue_custom_field_values_5").trigger('change')
    setTimeout (->
      relation = $(_this).data('relation')
      priority = relation[$(_this).val()]
      $("#issue_priority_id").val(priority) if !!priority), 100
    return

  ## User Avatar Upload
  $(".upload-avatar #avatar-input").on 'change', ->
    file = @files[0]
    return if !file or !window.FileReader
    # check if image file
    if !/.(jpg|jpeg|png)$/i.test(@value)
      layer.alert '只支持图片格式喔！'
      return
    # check image size
    size_in_megabytes = file.size / 1024 / 1024
    if size_in_megabytes > 3
      layer.alert '图片太大了，最大只支持3M的图片上传喔！'
      return
    # get image blob
    URLObj = window.URL or window.webkitURL
    source = URLObj.createObjectURL(file)
    # load cropper
    cropped = {file: file}
    layer.open
      type: 1
      title: '<b>头像裁减</b>'
      area: ['600px', '550px']
      zIndex: 666
      moveType: 1
      shadeClose: false
      content: "<div id='toUploadAvatar'><img src='#{source}'></img></div>"
      success: ->
        $("#toUploadAvatar > img").cropper
          aspectRatio: 1
          viewMode: 1
          crop: (e) ->
            cropped.x = e.x
            cropped.y = e.y
            cropped.width = e.width
            cropped.height = e.height
      btn: ['取消', '上传']
      yes: (index, layero) ->
        layer.close(index)
      btn2: (index, layero) ->
        formData = new FormData
        for key, value of cropped
          formData.append "avatar[#{key}]", value
        $.ajax
          url: '/my/avatar'
          type: 'POST'
          data: formData
          processData: false
          contentType: false
          success: (result) ->
            $(".large-avatar > img").prop("src", result.avatar_url)
          error: (responseStr) ->
            layer.alert('哎呀！上传失败了！');
      end: ->
        $(".upload-avatar #avatar-input").val('')

  ## Version Release
  ## View release log
  class ReleaseLog
    @new: (element) -> new ReleaseLog element
    constructor: (element) ->
      @$element = $(element)
      @log_url  = @$element.data("log")
      @$temp    = $("#content")
      @id       = 'log_' + @log_url.split("/").pop()
      @$content  = $('<div/>', {id: @id, class: 'release_log_pane'})
      @init()
    init: ->
      if $("##{@id}").length > 0 # Check if the element is already exsit
        @show()
      else
        _this = @
        $.getJSON(@log_url, (data) ->
          _this.log = data
          _this.initBar()
        ).fail -> layer.alert "哎哟，好像出了一点不可预料的小问题！"
    initBar: ->
      _this = @
      if typeof @log is "string" or @log.length == 0
        layer.alert "OH~ LOG已经被外星人抢走了！"
      else
        if @log.length > 1
          $bar = $("<div/>", {class: 'release_log_bar'})
          $select = $("<select/>", {change: -> _this.redraw $(this).val()})
          for num in [@log.length..1]
            $select.append $('<option>',
              value: num,
              text: "第 #{num} 次发布"
            )
          $bar
            .append $select
            .appendTo @$content
        @initContent()
    initContent: ->
        @$content.append @draw()
        @$temp.append @$content
        @show()
    draw: (num) ->
      num ||= @log.length
      json     = @log[num - 1] # first at present
      $table   = $('<table/>', {class: 'table table-striped'})
      $body    = $('<tbody/>')
      for key, value of json
        $tr =  $('<tr/>', {class: 'release_log_list'})
        $tr
          .append $("<td/>").text key.substring(key.length-19, key.length)
          .append $("<td/>").text value
          .appendTo $body
      $table.append $body
    redraw: (num) ->
      $("##{@id} .table").html @draw num
    show: ->
      layer.open
        type: 1
        title: '<b>日志详情</b>'
        area: ['700px', '600px']
        zIndex: 666
        moveType: 1
        shadeClose: false
        content: $("##{@id}")

  $(".view_release_log").on 'click', -> ReleaseLog.new this


  ## Periodic Version
  $('#versionForm').on 'change', '#version_project_id', ->
    $.ajax
      url: '/periodic_versions/new'
      type: 'post'
      data: $(this).closest('form').serialize()
    return


  ## Project Menu
  $(".project-menu li").has("ul").on 'click', '>a',  ->
    $(this).siblings().slideToggle() if /#|^javascript/.test(this.href)


  ## Issue
  $("#issueTable").on 'click', "a[href^='/issues/']", ->
    issue_id = @href.match(/\d+$/);
    localStorage.setItem("lastViewIssueID", issue_id[0]) if issue_id
    return


  ## Export list
  class ExportPanel
    constructor: ->
      @url      = '/exports'
      @$temp    = $("#content")
      @$content = $('<div/>', id: 'ExportPanel', class: 'export-pane-wrapper')
      @$noFileNotice = $("<div/>", class: 'export-no-files').text('无任何导出任务')
      @init()
    init: ->
      $('#ExportPanel').remove() if $('#ExportPanel').length > 0
      $.getJSON(@url, (data) =>
        @data = data
        badge = 0
        for dat in data
          badge++ if(dat.status == 1 || dat.status == 2)
        @changeBadge badge
        @initPanel()
      ).fail -> layer.alert "哎哟，好像出了一点不可预料的小问题！"
    changeBadge: (num) ->
      $('i.export-badge').attr('data-badge', num || 0)
    initPanel: ->
      html = $("<ul/>", {class: 'export-pane'})
      for dat in @data
        $li   = $("<li/>", class: "export-pane-list export-item-#{dat.id}", "data-id": dat.id)
        $body = $("<div/>", class: "export-pane-list-body export-format-#{dat.format}")
        $foot = $('<div/>', class: "export-pane-list-foot").append($('<a/>', href: 'javascript:void(0);', click: (e) => @deleteItem(e)).append $('<i>', class: 'fa fa-times-circle fa-lg'))
        $cf   = $('<div/>', class: "clearfix")
        switch dat.status
          when 1 # Queued
            $body.append($('<div/>').append($('<span/>', class: 'export-name').text(dat.name)))
                 .append($('<div/>').append($('<span/>', class: 'export-status').text(dat.status_text))
                                    .append($('<span/>', class: 'export-before-it pull-right').text("前面还有#{dat.before_it}个任务")))
          when 2 # Progressing
            $body.append($('<div/>').append($('<span/>', class: 'export-name').text(dat.name))
                                    .append($('<span/>', class: 'export-status pull-right').text(dat.status_text)))
                 .append($('<div/>').append($('<span/>', class: 'export-progress-bar')))
          when 3 # Completed
            $body.append($('<div/>').append($('<div />', class: 'export-name').text(dat.name))
                                    .append($('<span/>', class: 'export-filesize').text(dat.file_size))
                                    .append($('<a   />', class: 'btn btn-primary btn-xs export-download-btn pull-right', href: "/exports/#{dat.id}/download").text('下载')))
          when 4 # Failed
            $body.append($('<div/>').append($('<span/>', class: 'export-name').text(dat.name)))
                 .append($('<div/>').append($('<span/>', class: 'export-status').text(dat.status_text)))
        $li.append($body).append($foot).append($cf).appendTo(html)
      # show notice
      if @data.length > 0
        html.append $("<li/>", class: "export-notice").append $("<span/>").text('每个文件在服务器上最多保存三天')
      else
        html = @$noFileNotice
      @$content.append(html).appendTo(@$temp)
      @showPanel()
    showPanel: ->
      layer.open
        type: 1
        title: '<b>导出任务</b>'
        area: ['600px', '400px']
        zIndex: 666
        moveType: 1
        shadeClose: false
        content: $('#ExportPanel')
    deleteItem: (e) ->
      _this = @
      layer.confirm '确认从导出列表中移出吗？',
        btn: ['取消', '确认'],
        (index) ->
          layer.close index
        ->
          $target = $ e.target
          $li = $target.closest('li')
          $.post("/exports/#{$li.data('id')}", _method: "delete", ->
            $li.remove()
            if $('.export-pane li').length <= 1
              _this.changeBadge()
              $('#ExportPanel').empty().append(_this.$noFileNotice)
          ).fail -> alert "删除失败！请确认你是否有权限！"

  $(".nav-downlaod").click -> new ExportPanel
