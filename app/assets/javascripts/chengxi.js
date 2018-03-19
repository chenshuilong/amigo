// Chengxi's Javascripts
// Amigo Project Management System
// From 2016/6/13

// Public function
(function($){
  $.fn.select2_remote = function(arg) {
    var arg = arg || {};
    var holder = arg.holder || "--- 请选择 ---";
    var url = arg.url || "/users/assigned";
    var project = arg.project || "";
    var status = arg.status || "";
    var clear = this[0].hasAttribute("multiple") ? false : true;
    var withme = arg.withme == false ? false : true;
    this.addClass("ajax-loading");
    this.select2({
      allowClear: clear,
      placeholder: holder,
      ajax: {
        url: url,
        dataType: "json",
        delay: 250,
        data: function(params){
          var para = {name: params.term, page: params.page};
          if(!!project){para.project_id = project}
          if(!!status){para.status = status}
          para.withme = withme
          return para;
        },
        cache: true,
        processResults:  function (result, params) {
          var options = [];
          $.each(result, function(i, v){
            var option = {"id": v.id, "text": v.name};
            options.push(option);
          })
          return {
            results:  options,
            pagination:  {
              more: 2
            }
          };
        },
        escapeMarkup: function (markup) { return markup; },
        minimumInputLength: 1
      }
    });
  };
})(jQuery);

// Fix block
(function ($) {
  $.fn.fixedBlock = function (args) {
    var top = this.offset().top, timeId;
    this.css("position", "absolute");
    $(window).on('scroll', function(event) {
      if (timeId) clearTimeout(timeId);
      timeId = setTimeout(function () {
        if (($(event.target).scrollTop() + 10) >= top) {
          this.css({top: $(event.target).scrollTop() - top + 80});
        } else {
          this.css ({top: 0});
        }
      }.bind(this), 200)
    }.bind(this))
  }
})(jQuery);

// Super popover
(function($) {
  $.fn.superPopover = function (args) {
    var defaults = { html: true, animation: false};
    var params = $.extend(defaults, args);
    this.popover(params).on("mouseenter", function () {
      var _this = this;
      $(this).popover("show");
      $(".popover").on("mouseleave", function () {
          $(_this).popover('hide');
      });
    }).on("mouseleave", function () {
      var _this = this;
      setTimeout(function () {
        if (!$(".popover:hover").length) {
          $(_this).popover("hide");
        }
      }, 200);
    });
  }
})(jQuery);


// Select2 value change and trigger change event
(function($) {
  $.fn.select2_touch = function (args) {
    if(((typeof args == "string") && !args) || $.isEmptyObject(args)){
      this.val("").trigger('change.select2');
    } else if((typeof args == "object") && !$.isEmptyObject(args)) {
      if(this.find("option[value='" + args.id + "']").length) {
        this.val(args.id).trigger("change.select2");
      } else {
        var newState = new Option(args.firstname, args.id, true, true);
        this.append(newState).trigger('change.select2');
      }
    } else {
      this.val("").trigger('change.select2');
    }
  }
})(jQuery);

// Add Issue Log
(function($) {
  $.fn.addIssueLog = function (args) {
    var text_area = args.textarea;
    var html = '<div class="row form-horizontal" style="margin:20px;padding-left:20px;width:580px">\
                  <div class="form-group">\
                    <label class="col-sm-2 control-label">LOG时间</label>\
                    <div class="col-sm-9"><input type="text" class="form-control" id="logTime" ></div>\
                  </div>\
                  <div class="form-group">\
                    <label class="col-sm-2 control-label">LOG地址</label>\
                    <div class="col-sm-9"><input type="text" class="form-control" id="logAddr" placeholder="以附件方式上传LOG时请为空"></div>\
                  </div>\
                  <div class="form-group">\
                    <label class="col-sm-2 control-label">视频地址</label>\
                    <div class="col-sm-9"><input type="text" class="form-control" id="videoAddr" placeholder="选填"></div>\
                  </div>\
                </div>';
      layer.open({
        type: 1,
        title: '<b>添加LOG</b>',
        area: ['640px', 'auto'],
        zIndex: 666,
        moveType: 1,
        shadeClose: false,
        content: html,
        btn: ['取消', '确定'],
        yes: function (index, layero) {
          layer.close(index)
        },
        btn2: function (index, layero) {
          var log_time   = $('#logTime').val();
          var log_addr   = $('#logAddr').val();
          var video_addr = $('#videoAddr').val();

          if(!log_time) {layer.alert('LOG时间不可以为空！'); return false;}
          if(!!log_addr && !/^ftp:\/\//.test(log_addr)) {layer.alert('LOG地址不合法，需以 ftp:// 开头！'); return false;}

          log_text = (!text_area.value || /\n$/.test(text_area.value)) ? '' : '\n';
          log_text += '【LOG时间】' + log_time + '\n';
          log_text += '【LOG地址】' + (log_addr || '见附件');
          if(!!video_addr){ log_text += '\n' + '【视频地址】' + video_addr}

          text_area.value += log_text;
        },
        success: function(){
          $(function() {
            $('#logTime').periodpicker({
              likeXDSoftDateTimePicker: true,
              formatDateTime:'YYYY-MM-DD HH:mm',
              lang: 'zh',
              animation: false,

              norange: true, // use only one value
              cells: [1, 1], // show only one month

              resizeButton: false, // deny resize picker
              fullsizeButton: false,
              fullsizeOnDblClick: false,
              yearsLine: false,

              timepicker: true, // use timepicker
              timepickerOptions: {
                hours: true,
                minutes: true,
                seconds: false,
                twelveHoursFormat: false,
                ampm: false
              }
            });
          });
        }
    });
  }
})(jQuery);

// Add Issue Log validation
(function($) {
  $.fn.addIssueLogValidate = function (args) {
    $form = this.closest('form');
    $form.off("submit").on("submit", function(e){
      // Check new issue or edit issue
      var new_record = window.location.href.match(/\/(issues|new|copy)$/) ? true : false;

      if(new_record) { // check description
        val = $form.find("#issue_description").val()
      } else { // check note
        val = $form.find("#issue_notes").val()
      }

      if(!!val && /ftp:\/\/.+\.(zip|rar)/i.test(val) && /(^|[^\w]+)log[^\w\n]/i.test(val)){
        if (!(/【LOG时间】\s*\d+\-\d+\-\d+\s+\d+\:\d+/i.test(val) && /【LOG地址】\s*((ftp:\/\/.+\.(zip|rar))|见附件)/.test(val))){
          e.preventDefault();
          setTimeout(function(){
            $form.removeAttr("data-submitted");
          });
          layer.alert("LOG填写不规范！为了支持自动化分析工具，请按正确格式填写再提交！");
          return false;
        }
      }

    });
  }
})(jQuery);


// Submit button float bottom
$(document).ready(function(){
  (function ($) {
    floatSubmitButton($("div.button-group"));
    function floatSubmitButton(element){
      if(!element.length){return;}
      var $this = $(element);
      var top = $this.offset().top;
      $(window).on('scroll', function (e) {
        // console.log(top+", "+$(e.target).scrollTop()+", "+$(window).height())
        if(!top && $this.is(":visible")){ top = $this.offset().top } // Reset top
        if(!top){return;}
        if ($(e.target).scrollTop() + $(window).height() >= top) {
          $this.removeClass('navbar-fixed-bottom');
        } else {
          $this.addClass('navbar-fixed-bottom');
        }
        if($(window).scrollTop() + $(window).height() == $(document).height()) { // Reset top
          top = $this.offset().top;
          $this.removeClass('navbar-fixed-bottom');
        }
      }).trigger('scroll');
    }
  })(jQuery);
});

// Limit max input length
// eg: data-max-input-length = "1226"
$(document).ready(function(){
  (function ($) {
    function limitInput(element, length) {
      var $el = $(element);
      $el.on("input", function(){
        var val = $(this).val();
        var val_count = val.length;
        var max_num = length;
        if(val_count >= max_num) {
          $(this).siblings(".inline").html("<span class='text-danger'>" + max_num + "</span>/" + max_num);
          $(this).val(val.substring(0, max_num));
        } else {
          $(this).siblings(".inline").html(val_count + "/" + max_num);
        }
      })
    }
    // Initialize
    $('[data-max-input-length]').each(function(){
      var limit = $(this).data("max-input-length") || 0;
      var val = $(this).val().length;
      $(this).parent().append($("<span class='inline'/>").text(val + "/" + limit));
      limitInput(this, limit);
    });
  })(jQuery);
});


// Ready to perform function
$(document).ready(function(){

  //Navigation
  $(".nav-search .fa").click(function(){$(".nav-search form").submit();})

  // Show Top Notice
  if($(".top-notice").length > 0) {setTimeout(function() {$(".top-notice").slideDown(); }, 800)}
  // Close Top Notice
  $("#closeTopNotice").click(function(){
    var $parent = $(this).closest(".top-notice");
    var key = $(this).closest(".top-notice").data().key;
    $parent.slideUp();
    Cookies.set("top_notice", key, {expires: 30, path: '/'})
  })

  // Issues index

  ////////// Filter Condition folder and files pane ////////////
  if($('#filterStarList').length > 0) {
    // Initialize
    var et = $('#filterStarList').easytree({
      enableDnd: true,
      ordering: 'ordered ASC',
      dropped: dropped,
      toggled: rememberExplandID
    });
    var et_hr = $('#filterHistoryList').easytree();
    var et_st = $('#filterSystemList').easytree({
      enableDnd: true,
      dropped: dropped,
      toggled: rememberExplandID
    });

    // Loading folder expand
    store = (localStorage.getItem("treeData") || "").split(",")
    if(store.length > 0){
      // Star
      var nodes = et.getAllNodes();
      changeTreeNode(nodes, store);
      et.rebuildTree(nodes)
      // System
      var nodes_st = et_st.getAllNodes();
      changeTreeNode(nodes_st, store);
      et_st.rebuildTree(nodes_st)
    }
    // Loading Highlight Condition Item
    match_condition_id = location.search.match(/condition_id=([^&]+|$)/)
    if(!(match_condition_id === null)){
      easy_tree = filterCollapseID == "filterStar" ? et : (filterCollapseID == "filterClock" ? et_hr : et_st)
      var nodes = easy_tree.getAllNodes();
      highlightCondition(nodes, match_condition_id[1])
      easy_tree.rebuildTree(nodes)
    }
  }

  //Show History pane

   // More for Filter, show filter menu
  $(".filter-list-name").on("click", "div.filter-more", function(e){
    event.stopPropagation();
    easy_tree = returnEasyTree(this)
    node_id = $(this).closest("span.easytree-node").attr("id");
    target_for_ID = $("#" + node_id).find(".easytree-title a").attr("target")
    $id = $(this).closest(".panel-body").find(".filter-menu")
    if(easy_tree.getNode(node_id).isFolder){
      $id.find(".forfolder").show()
      $id.find(".forfile").hide()
    }else{
      $id.find(".forfile").show()
      $id.find(".forfolder").hide()
    }
    if($id.is(':hidden') || node_id != targetID) {
      var top = $(this).offset().top + 20;
      var left = $(this).offset().left + 20;
      $id.show().offset({top:top,left:left});
      targetID = node_id
    } else {
      $id.hide();
    }
  });

  // New filter Window
  $(".filter-add-icon, .filter-menu-newcondition").click(function(){
    // Set Target_for_ID
    var category = 1
    if($(this).hasClass("filter-menu-newcondition")){
      $('.filter-window-targetID-value').val(target_for_ID)
      easy_tree = returnEasyTree(this)
      if(easy_tree != et) {
        if(window.location.toString().indexOf("issue") > -1)
          category = 2
        else
          category = 4
      } else {
        if(window.location.toString().indexOf("issue") > -1)
          category = 1
        else
          category = 3
      }
    }
    else
      $('.filter-window-targetID-value').val("")
    // Empty conditions pane and columns pane
    $(".filter-pane").empty()
    $(".filter-window-right-body").empty()
    // Intialize Window
    $(".filter-pane")
      .append($("<li/>"))
      .children("li").append($(".filter-window-group").clone()).append($("<ul/>"))
      .find("ul").append($("<li/>")).children("li").append($(".filter-window-element").clone())
    // Default add active to control-conditions tab
    $(".filter-window-control-conditions").trigger("click");
    // Open Filter Window
    filter_window = layer.open({
      type: 1,
      title: '<b>新建查询</b>',
      area: ['650px', 'auto'],
      zIndex: 888,
      moveType: 1,
      shadeClose: false,
      content: $('.filter-window'),
      btn: ['取消', '确定'],
      success: function(layero, index){
       initSelect()
      },
      yes: function(index, layero){
        layer.close(filter_window)
      },
      btn2: function(index, layero){
        new_name = $(".filter-window-name-value").val()
        if(new_name.replace(/\s/g,"") == "") {
          alert("文件名不可为空")
          return false
        }
        if($(".filter-pane").children("li").length>1){
          alert("最外层条件需要合并成组！")
          return false
        }
        var column_order = []
        $(".filter-window-right-body").find(":checked").each(function(){column_order.push($(this).attr("for"))})

        column_order = column_order.toString()
        new_name = $(".filter-window-name-value").val()
        target_for_ID = $(".filter-window-targetID-value").val()
        project_id = $(".filter-window-projectID-value").val()
        condition_json = JSON.stringify(getTreeJson($('.filter-pane')))

        // console.log(condition_json)
        $.post("/conditions"
          ,{condition: {category: category, name: new_name, folder_id: target_for_ID, column_order: column_order, project_id: project_id, json: condition_json}}
          ,function(result){
            window.location.search = "condition_id=" + result
          })
          .fail(function() {
            alert( "查询失败！请确认你是否有权限！" );
            layer.close(filter_window)
          })
      }
    });
    $(".filter-window-name-value").val("").focus()
    //Load Columns
    $.getJSON("/conditions/conditioncolumn",
    function(result){
      renderColumns(result)
    }).fail(function(){
      alert("网络出现故障！")
    })
  });

  //DoubleClick to Open condition
  $(".filter-list").on("dblclick", "span.easytree-ico-c", function(){
    condition_id = $(this).find("a").attr("target")
    openConditionURL(condition_id)
  });

  // Menu, when newfolder
  $('.filter-menu-newfolder, .panel-heading-newfolder').click(function(e){
    e.stopPropagation();
    $(".filter-menu").hide();
    if($(this).hasClass("panel-heading-newfolder")){
      targetID = ""
      target_for_ID = ""
    }
    easy_tree = returnEasyTree(this)
    if(easy_tree != et){
      if(window.location.toString().indexOf("issue") > -1)
          category = 2
      else
          category = 4
    } else {
      if(window.location.toString().indexOf("issue") > -1)
        category = 1
      else
        category = 3
    }
    newfolder_window = layer.open({
      type: 1,
      title: '<b>新建文件夹</b>',
      area: ['400px', 'auto'],
      zIndex: 888,
      moveType: 1,
      content: $('#filterStarNewforlder'),
      btn: ['取消', '确定'],
      yes: function(index, layero){
        layer.close(newfolder_window)
      },
      btn2: function(index, layero){
        new_name = $(".filter-window-newfolder-value").val()
        if(new_name.replace(/\s/g,"") == "") {
          alert("文件名不可为空")
          return false
        }
        else {
          $.post("/conditions"
            ,{condition: {category: category, name: new_name, is_folder: true, folder_id: target_for_ID }}
            ,function(result){
              var sourceNode = {};
              sourceNode.text = new_name;
              sourceNode.isFolder = 'true';
              sourceNode.href = 'javascript:;';
              sourceNode.hrefTarget = result;
              easy_tree.addNode(sourceNode, targetID);
              easy_tree.rebuildTree();
            })
            .fail(function() {
              alert( "创建失败！请确认你是否有权限！" );
            })
        }
      }
    });
    $(".filter-window-newfolder-value").val("").focus()
  });

  // Menu, when copy
  $('.filter-menu-copy').click(function(){
    $("#filter-menu-past").show()
    copyID = targetID
  });

  // Menu, when past
  $('.filter-menu-past').click(function(){
    if(copyID == "" || copyID == "undefined") {return}

    // Get Past to ID
    pastID = et.getNode(targetID).isFolder ? targetID : targetParentID()
    from_for_ID = et.getNode(copyID).hrefTarget
    folder_id = pastID == '' ? '' : et.getNode(pastID).hrefTarget

    $.post("/conditions/" + from_for_ID
    ,{_method:'put', keep_update: false, condition: { folder_id: folder_id }}
    ,function(result){
      var sourceNode = {};
      sourceNode.text = et.getNode(copyID).text + " - 副本";
      sourceNode.href = 'javascript:;';
      sourceNode.hrefTarget = result;
      et.addNode(sourceNode, pastID);
      et.rebuildTree();
      if(pastID == targetID && !et.getNode(pastID).isExpanded){ et.toggleNode(pastID) }

      $("#filter-menu-past").hide();
      copyID = "";
    })
    .fail(function() {
      alert( "粘贴失败！请确认你是否有权限！" );
    })
  });

  // Menu, when delete
  $('.filter-menu-delete').click(function(){
    easy_tree = returnEasyTree(this)
    isFolder = easy_tree.getNode(targetID).isFolder
    if(isFolder)
      sure_delete = confirm("删除文件夹，将会删除文件夹内部的所有文档，确定删除吗？")
    else
      sure_delete = confirm("确定删除吗？")
    if(sure_delete) {
      $.post("/conditions/" + target_for_ID
      ,{_method: "delete"}
      ,function(){
        var node = easy_tree.getNode(targetID);
        if (!node) { return; }
        easy_tree.removeNode(node.id);
        easy_tree.rebuildTree();

        var re = new RegExp("condition_id=" + target_for_ID)
        if(re.test(location.href)){ location.search = "" }
      })
      .fail(function() {
        alert( "删除失败！请确认你是否有权限！" );
      })
    }
  });

  //Menu, when Open
  $('.filter-menu-open').click(function(){
    easy_tree = returnEasyTree(this)
    condition_id = easy_tree.getNode(targetID).hrefTarget
    openConditionURL(condition_id)
  })

  //Menu, when Edit
  $('.filter-menu-edit, .filter-menu-systemedit, .issues-head-function-changeColumns').click(function(){
    // Intialize Window
    $(".filter-pane").empty()
    $(".filter-window-right-body").empty()
    // Default add active to control-conditions tab

    if($(this).hasClass("issues-head-function-changeColumns"))
      {$(".filter-window-control-columns").trigger("click"); target_for_ID = window.location.search.match(/condition_id=([^&]+|$)/)[1]}
    else
      {$(".filter-window-control-conditions").trigger("click");}

    if($(this).hasClass("issues-head-function-changeColumns")){
      keep_update = true
    } else if(returnEasyTree(this) == et_st) {
      if($(this).hasClass("filter-menu-systemedit")){keep_update = true} else {keep_update = false}
    } else {
      keep_update = true
    }

    // Get Condition info
    $.getJSON("/conditions/conditioninfo?id=" + target_for_ID,
      function(condition){
        //Render Window contents
        $(".filter-window-name-value").val(condition.name)
        setTreeNode($('.filter-pane'), JSON.parse(condition.json), condition.users)
        renderColumns(condition.column_order, condition.column_count)
        // Load Editing Window
        edit_window = layer.open({
          type: 1,
          title: '<b>编辑</b>',
          area: ['650px', 'auto'],
          zIndex: 888,
          moveType: 1,
          shadeClose: false,
          content: $('.filter-window'),
          btn: ['取消', '确定'],
          yes: function(index, layero){
            layer.close(edit_window)
          },
          btn2: function(index, layero){
            new_name = $(".filter-window-name-value").val()
            if(new_name.replace(/\s/g,"") == "") {
              alert("查询条件名称不能为空！")
              return false
            }
            if($(".filter-pane").children("li").length>1){
              alert("最外层条件需要合并成组！")
              return false
            }
            var column_order = []
            $(".filter-window-right-body").find(":checked").each(function(){column_order.push($(this).attr("for"))})
            column_order = column_order.toString()
            new_name = $(".filter-window-name-value").val()
            condition_json = JSON.stringify(getTreeJson($('.filter-pane')))

            $.post("/conditions/" + target_for_ID
              ,{_method:'put', keep_update: keep_update, condition: {name: new_name, column_order: column_order, json: condition_json}}
              ,function(result){
                openConditionURL(result)
              })
              .fail(function() {
                alert( "编辑失败！请确认你是否有权限！" );
                layer.close(edit_window)
              })
          }
        });
      })
      .fail(function(){
        alert("网络出现故障！")
      });
    })

  //Menu, when Rename
  $('.filter-menu-rename').click(function(){
    $(".filter-menu").hide();
    easy_tree = returnEasyTree(this)
    rename_window = layer.open({
      type: 1,
      title: '<b>重命名</b>',
      area: ['400px', 'auto'],
      zIndex: 666,
      moveType: 1,
      shadeClose: false,
      content: $('#filterStarRename'),
      btn: ['取消', '确定'],
      yes: function(index, layero){
        layer.close(rename_window)
      },
      btn2: function(index, layero){
        new_name = $(".filter-window-rename-value").val()
        if(new_name.replace(/\s/g,"") == "") {
          alert("文件名不可为空")
          return false
        }
        else {
          $.post("/conditions/" + target_for_ID
          ,{_method:'put', keep_update: true, condition: {name: new_name}}
          ,function(){
            easy_tree.getNode(targetID).text = new_name
            easy_tree.rebuildTree();
          })
          .fail(function() {
            alert( "重命名失败！请确认你是否有权限！" );
          })
        }
      }
    });
    $(".filter-window-rename-value").val(easy_tree.getNode(targetID).text).focus()
  });

  // Menu, when Sendto
  $(".filter-menu-sendto").click(function(){
    var category = 1
    if(window.location.toString().indexOf("report") > -1)
      category = 3

    $.post("/conditions/" + target_for_ID
      ,{_method:'put', keep_update: false, condition: {}, category: category}
      ,function(result){
        localStorage.setItem("filterCollapseID", "filterStar");
        openConditionURL(result)
      })
      .fail(function() {
        alert( "转到我的自定义失败！请确认你是否有权限！" );
      })
  })

  //Menu, when Share
  $('.filter-menu-share').click(function(){
    $(".filter-window-select-list").empty();
    $(".select-window-select-result").empty();
    $(".filter-window-search input").attr('data-value-was', "").val("");
    $("#share_condition_id").val(target_for_ID);
    share_window = layer.open({
      type: 1,
      title: '<b>分享</b>',
      area: ['600px', 'auto'],
      zIndex: 666,
      moveType: 1,
      shadeClose: false,
      content: $('#filterStarShare'),
      btn: ['取消', '确定'],
      yes: function(index, layero){
        layer.close(share_window)
      },
      btn2: function(index, layero){
        if($(".select-window-select-result").find(":checked").length < 1){
          layer.alert("尚未选择任何分享对象！");
          return false;
        } else {
          $("#shareForm").submit();
        }
      }
    });
  });
  // load json of users or depts
  var tmpJson;
  $(".filter-window-search").on("input", "input", function(){
    $this = $(this);
    val = $(this).val().trim();
    if(!val) {
      $(".filter-window-select-list").empty();
      $this.attr('data-value-was', val);
      return false
    }
    if($this.attr('data-value-was') == val) {return false}
    $this.attr('data-value-was', val);
    $this.addClass("ajax-loading"); // Hide ajax aminate
    $.getJSON("/users/search", {name: val}).done(
      function(result){
        tmpJson = result;
        $this.removeClass("ajax-loading"); // Recover ajax aminate
        html = $('<ul class="list-group"/>');
        $.each(result, function(i, v){
          if(!v.name || $("#"+ v.type + "-" + v.id).length > 0) {return}
          $('<li/>').append(
            $('<button/>', {
              "data": v,
              "text": "添加",
              "class": "filter-window-select-add btn btn-default btn-sm"
            }),
            $('<span/>').text(v.name)
          ).appendTo(html)
        })
        $(".filter-window-select-list").html(html)
      })
  })

  // Add users or depts
  $(".filter-window-select-list").on("click", ".filter-window-select-add", function(){
      id = $(this).data().id;
      name = $(this).data().name;
      type = $(this).data().type;
      $(this).closest("li").remove();
      item = $('<li/>',{"id": type + "-" + id}).append(
        $('<input/>', {
          "type": "checkbox",
          "checked": "checked",
          "value": id,
          "name": "share["+type+"_ids][]"
        }),
        $('<span/>').text(name),
        $('<i/>',{
          "class": "fa fa-times",
          "click": function(){
            $(this).closest("li").remove()
          }
        })
      );
      $(".select-window-select-result").append(item)
  })


  // Custom function

  function targetParentID() {
    if (targetID.split('_').length > et.getAllNodes()[0].id.split("_").length)
      return targetID.replace(/_\d+$/,'')
    else
      return ''
  }

  function dropped(event, nodes, isSourceNode, source, isTargetNode, target) {
    var target_for_ID = source.hrefTarget
    var target_folder_for_ID = target.hrefTarget
    if(!target_folder_for_ID || !target_folder_for_ID) {return false;}
    $.post("/conditions/" + target_for_ID
      ,{ _method:'put', keep_update: true, condition: {folder_id: target_folder_for_ID}}
      )
    .fail(function() {
      alert( "移动失败！请确认你是否有权限！" );
    })
  }

  function rememberExplandID(event, nodes, node) {
    if (!window.localStorage) return;
    store = (localStorage.getItem("treeData") || "").split(",");
    if (node.isExpanded) {
      store.push(node.hrefTarget)
    } else {
      for (var i=0, len=store.length; i<len; i++){
        if (store[i] == node.hrefTarget) {
          store.splice(i, 1);
          break;
        }
      }
    }
    localStorage.setItem("treeData", store.join(','));
  }

  function changeTreeNode(nodes, store) {
    if (!nodes || !store) return;
    for (var i=0, nLen= nodes.length; i<nLen; i++){
      if (!nodes[i].isFolder) continue;
      for (var j=0, sLen=store.length; j<sLen; j++) {
        if (store[j] == nodes[i].hrefTarget) {
          nodes[i].isExpanded = true;
          break;
        }
      }
      if (nodes[i].children && nodes[i].children.length) {
        arguments.callee(nodes[i].children, store);
      }
    }
  }

  function highlightCondition(nodes, id) {
    if (!nodes || !id) return;
    active_find = false;
    for (var i=0, nLen= nodes.length; i<nLen; i++){
      if(nodes[i].hrefTarget == id){
        nodes[i].isActive = true;
        url_condition_id = ""
        break;
      }
      if (nodes[i].children && nodes[i].children.length) {
        arguments.callee(nodes[i].children, id);
      }
    }
  }


  function renderColumns(columns, count){
    $column_example = $(".filter-window-right-example")
    $column_for = $column_example.find(".column_for")
    $column_text = $column_example.find(".column_text")
    $.each(columns, function(k, v){
      if (v === "" || v === null) {return true}
      $column_for.attr("for", v.for)
      $column_text.text(v.text)
      $column_for.attr("checked", false);
      if(!count){
        default_checked = /project|status$|priority|subject|^assigned_to|updated_on|mokuai_name/.test(v.for) ? true : false
        $column_for.attr("checked", default_checked)
      } else if(count && k < count) {
        $column_for.attr("checked", true);
      }
      $(".filter-window-right-body").append($column_example.html())
    });
  }


 function returnEasyTree(id){
    closest_id = $(id).closest(".panel").find(".panel-collapse")[0].id
    if(closest_id == "filterStar")
      return et
    else if (closest_id == "filterClock")
      return et_hr
    else if (closest_id == "filterCog")
      return et_st
  }

  function openConditionURL(id){
    if(id){
      windowSearch = window.location.search
      new_reg = new RegExp("condition_id=" + id + "(&|$)")
      condition_match = windowSearch.match(new_reg)
      if(!condition_match || windowSearch.match("word|page"))
        {window.location.search = "condition_id=" + id}
      else
        {window.location.reload()}
    }
  }

  ///////////// Filter Window /////////////
  //Switch conditions AND columns display
  $(".filter-window-control-conditions, .filter-window-control-columns").click(function(){
    if(!$(this).hasClass("active"))
      $(this).siblings().removeClass("active").end().addClass("active")
    if($(".filter-window-control-conditions").hasClass("active")){
      $(".filter-window-left").show()
      $(".filter-window-right").hide()
    } else {
      $(".filter-window-left").hide()
      $(".filter-window-right").show()
    }
  })


  function renderFilterValue(id, key, users){
    var users = users || [];
    $this = $(id)
    $this.siblings(".select2-container").remove()
    $this.siblings(".value").remove()
    if(/assigned_to_id|ls_assigned_to_id|user|watcher_id|author_id|tfde_id/.test(key) || availableFilters[key].name == "发现者"){
      $this.siblings(".relation").after('<select multiple class="value form-control select-multiple remote", data-tag="filter" ></select>')
      if(users.length > 0){
        $.each(users, function(i, v){ $this.siblings(".value").append("<option value='"+v[0]+"'>"+v[1]+"</option>") });
      }
      $this.siblings(".value").select2_remote();
      return;
    } //Load History Assigned To AND Founder

    result = availableFilters[key]
    if(/list|bool|user/.test(result.type)){
      $this.siblings(".relation").after('<select multiple class="value form-control select-multiple", data-tag="filter" ></select>')
      $.each(result.values, function(i, v){
        if($.isArray(v))
          if(key != "dept_id") {
            $this.siblings(".value").append("<option value='"+v[1]+"'>"+v[0]+"</option>")
          } else {
            $group = $('<optgroup/>',{ label: v[0] })
            $.each(v[1], function(i, vv){
              $group.append("<option value='"+vv[1]+"'>"+vv[0]+"</option>")
            })
            $this.siblings(".value").append($group)
          }
        else
          $this.siblings(".value").append("<option value='"+v+"'>"+v+"</option>")
      })
      $this.siblings(".value").select2({placeholder: "请选择对应值", closeOnSelect: false})
    } else {
      $this.siblings(".relation").after('<input type="text" class="value form-control '+result.type+'" data-tag="filter">')
      if(/date/.test(result.type))
        $this.siblings(".value").periodpicker({
          likeXDSoftDateTimePicker: true,
          formatDate:'YYYY-MM-DD',
          lang: 'zh',
          animation: false,
          norange: true, // use only one value
          cells: [1, 2], // show only one month
          resizeButton: false, // deny resize picker
          fullsizeButton: false,
          fullsizeOnDblClick: false,
          withoutBottomPanel: true
        });
    }
  }


  function operatorValue(div){
    return div.find(".operator").val()
  }


  // Check all
  $(".filter-window-pickall").click(function(){
    $(".filter-pane :checkbox").prop('checked', $(this).find(":checkbox").prop("checked"));
  });

  // Change AND OR display
  $(".filter-pane").on("click", "div.filter-window-group-relation", function(){
    span_text = $(this).find("span").text() == "并且" ? "或" : "并且"
    input_value = span_text == "并且" ? " AND " : " OR "
    $(this).find("span").text(span_text)
    $(this).find("input").val(input_value)
  }).on("click", '.folding', function (event) {
    $(this).hasClass('fa-caret-down') ?
      $(this)
        .removeClass('fa-caret-down')
        .addClass('fa-caret-right')
        .closest('.isgroup')
        .siblings('ul')
        .fadeOut('fast') :
        $(this)
          .removeClass('fa-caret-right')
          .addClass('fa-caret-down')
          .closest('.isgroup')
          .siblings('ul')
          .fadeIn('fast');
  });

  // Delete
  $(".filter-pane").on("click", "a.filter-window-element-delete, a.filter-window-group-delete", function(){
    $(this).closest("li").remove();
  });

  // Add
  $(".filter-pane").on("click", "a.filter-window-element-add, a.filter-window-group-delete", function(){
    if($(this).closest(".closest-div").hasClass("isgroup")){
      var this_ul = $(this).closest("li").children("ul"),
        li = '<li>' + $(".filter-window-element").prop("outerHTML") + '</li>';
    this_ul.prepend(li);
    } else {
      var this_li = $(this).closest("li"),
        li = '<li>' + $(".filter-window-element").prop("outerHTML") + '</li>';
      this_li.after(li)
    }
    initSelect();
  });

  // Merge
  $("#filter-func-merge").click(function(){
    var merge_status;
      $(".filter-pane input:checked").each(function(index, Element){
        if (!$.isNumeric(merge_status)) merge_status = getLayer(Element).virtual;
        if (merge_status !== getLayer(Element).virtual) {
          alert("暂无法进行此合并！");
          merge_status = false;
          return false;
        }
    });
    if (merge_status === false) return;
    var html = "<li>" + $(".filter-window-group.isgroup").prop("outerHTML") +"<ul class='mergeing'></ul></li>";
    $(".filter-pane input:checked").each(function(index, Element){
      var layer = getLayer(Element);
      if (layer.virtual == layer.real) {
        if ($.isNumeric(merge_status)) merge_status = $(Element).closest('li').before(html);
        $('.filter-pane .mergeing').append($(Element).closest('li'));
      }
    });
    $('.filter-pane .mergeing').removeClass('mergeing');
    $(".filter-pane :checkbox").prop('checked', false);
  });

  //Custom Fuction for Filter
  function getLayer(element, i, j) {
    var i = i || 0, j = j || 0,
        $ul = $(element).closest('li').parent();
    if ($ul.hasClass('filter-pane')) return {virtual: i , real: j};
    return $ul.siblings('.isgroup').length && $ul.siblings('.isgroup').find("input:checked").length ?
        arguments.callee($ul, i, ++j) : arguments.callee($ul, ++i, ++j)
  }

  function getTreeJson(ul, obj) {
    var obj = obj || {},
        $ul = $(ul),
        $lis = $ul.children('li'),
        $div, value, fn = arguments.callee;
    $lis.each(function (index, Element) {
        $div = $(Element).children('div');
      if (!$div.length) return false;
      if ($div.hasClass('isgroup')) {
        value = $div.find('.filter-window-group-relation input').val();
        obj[value + index] = {};
        fn($div.siblings('ul'), obj[value + index]);
      } else {
        value = [];
        $('[data-tag="filter"]', $div).each(function (index, Element) {
          value.push ($(Element).val())
        });
        obj[index] = value
      }
    });

    return obj;
  }

  function setTreeNode(ul, json, users) {
    var $ul = $(ul), $li, fn = arguments.callee;
    if (!json) return;
    for (var i in json) {
      var arr = i.trim().split(/\s+/);
      if ($.isNumeric(+arr[0])){
        $li = getElementLi();
        renderFilterValue($li.find(".category"), json[i][0], users) // Render Value before Assignment
        $('[data-tag="filter"]', $li).each(function (index, Element) {
          $(Element).val(json[i][index]);
        });
         $ul.append($li);
      } else {
        $li = getGroupLi();
        $li.find('.filter-window-group-relation')
            .find('input[type=hidden]').val(' ' + arr[0]+ ' ').end()
            .find('span').text(arr[0] == 'OR' ? '或' : '并且');
        fn($li.children('ul'), json[i], users);
        $ul.append($li);
      }
    }
    initSelect();
  }

  function getElementLi() {
    var $div, $li;
    $div = $(".filter-window-element:first").clone();
    $li = $('<li />').append($div);
    return $li;
  }

  function getGroupLi() {
    var $div, $li;
    $div = $(".filter-window-group:first").clone();
    $li = $('<li />').append($div).append('<ul />');
    return $li
  }

  function initSelect() {
    var all_select = $('.filter-pane select.select-multiple');
    all_select.not(".remote").select2({placeholder: "请选择对应值", closeOnSelect: false});
    all_select.trigger("change");
  }


  // Head Button Add
  $("#filter-func-add").click(function(){
    $this_li = $(".filter-pane").prepend('<li>' + $(".filter-window-element").prop("outerHTML") + '</li>');
    $this_li.find(".value").select2({
      placeholder: "请选择对应值",
      closeOnSelect: false
    });
  });

  // Head Button delete
  $("#filter-func-delete").click(function(){
    $(".filter-pane input:checked").closest("li").remove();
  });

  // Click group CheckBox to selet all nodes CheckBox
  $(".filter-pane").on("click", "input[type='checkbox']", function(){
    this_group = $(this).closest(".closest-div")
    if(this_group.hasClass("isgroup"))
      this_group.next().find(":checkbox").prop('checked', $(this).prop('checked'));
  });

  // Return value when Select category
  $(".filter-pane").on("change", "select.category", function(){
    key = $(this).val()
    $this = $(this)
    renderFilterValue($this, key)
  });

  // Handle to sort columns order
  var fixHelper = function (e, ui) {
    ui.children().each(function () { $(this).width($(this).width()); });
    return ui;
  };

  $(".filter-window-right-body").sortable({
      helper: fixHelper,
      handle: '.sort-handle',
  }).disableSelection().on("click", ".table-row", function(){
    $(this).siblings().removeClass("table-row-grey").end().addClass("table-row-grey")
    if($(".filter-window-right-body").find(":checked").length < 1) {alert("未选择任何显示字段，我们将会为你载入默认字段喔！")}
  });


  // Filter Pane slide left
  $(".filter-slide-button").click(function(){
    if($(".filter-main").hasClass("filter-slide")){
      $(".filter-main").removeClass("filter-slide")
      $(".filter-slide-button i").removeClass("fa-chevron-right")
      Cookies.remove('filterSlideStatus', {path: '/' })
    } else {
      $(".filter-main").addClass("filter-slide")
      $(".filter-slide-button i").addClass("fa-chevron-right")
      Cookies.set("filterSlideStatus", true, {expires: 365, path: '/'})
    }
  })

  // Export csv, xlsx window

  $(".issues-wrapper a.csv, .issues-wrapper a.xlsx").click(function(e){
    e.preventDefault()
    fileType = this.className
    $("#export-form").attr("action", location.pathname + "." + fileType)
    export_window = layer.open({
      type: 1,
      title: '<b>导出' + fileType.toUpperCase() + '文件</b>',
      area: ['400px', 'auto'],
      zIndex: 666,
      moveType: 1,
      shadeClose: false,
      content: $('#export-options'),
      btn: ['取消', '确定'],
      yes: function(index, layero){
        layer.close(export_window)
      },
      btn2: function(index, layero){
        $("#export_ids").val(
          $("#issueTable tbody").find('.hide-when-print :checked').map(function(){
            return $(this).val();
          }).get().join(",")
        );
        $.get($("#export-form").attr("action"), $("#export-form").serialize())
          .done(function(){
            $("body").animate({"scrollTop": "0px"}, 500, function(){
              var $export_icon = $('.nav-downlaod i.fa')
              $export_icon.attr('data-badge', ~~$export_icon.attr('data-badge') + 1)
              layer.tips('导出任务已添加！', $export_icon, {tips: [4, '#3F3F3F']});
            });
          })
          .fail(function() {
            layer.alert("导出失败，请确认你是否有权限！")
          })
      }
    });
  })


  // Quickly search based on Current issues result
  $(".issues-head-function-form").submit(function(){
    var word = $("#word").val();

    // Parse all number
    var regex   = /\d+/g,
        results = [],
        n;

    while(n = regex.exec(word)) {
      results.push(parseInt(n[0]));
    }

    if (results.length >= 5){
      $("#word").val(results.join("."))
    } else {
      $("#word").val(word.split(/\s+/).join("."))
    }

  })


  // Issue Breifly Display
  $("tr.issue", "#issueTable").click(function(e){
    if (e.shiftKey || e.ctrlKey) {return}
    if(!e.target.nodeName.match(/A|INPUT/)){
      // $(this).addClass("highlight").siblings().removeClass("highlight");
      shoud_ajax =  $("#issue-preview").length < 0 || $("#issue-preview").prev().attr("id") != this.id
      $("#issue-preview").remove();
      if(shoud_ajax) { $.get("/issues/" + this.id.split("-")[1] + "/breifly"); }
    }
  })


  /////////////// Click Document to close ALL
  $(document).click(function(){
      $(".filter-menu").hide();
  });

  ///////////////// Issues page slider ///////////


  if($(".issues-wrapper").length > 0){
    var issue_table = $("table.issues")
    var issue_table_container = $(".autoscroll")
    $('input[type="range"]').rangeslider({
      polyfill: false,
      onInit: function() {},
      onSlide: function(position, value) {
        issue_table_width = issue_table.width()
        issue_table_container_width = issue_table_container.width()
        distance = (issue_table_width - issue_table_container_width)*(parseInt(value)/100)
        issue_table_container.scrollLeft(distance)
      }
    });
  }

  /////Issue New page

  $('.new_issue .issue-switch li').click(function(){
    // Slider animation
    p_status = $("#rom_version_p").is(":hidden")
    $(this).addClass('active').siblings().removeClass('active');
    $('.issue-switch ul i').stop(false,true).animate({'left': ($(this).position().left + $(this).width()*0.5 - 75)}, 200);
    // Show or hide Rom version select
    var needLoad = (p_status && $(this).index() == 0) || (!p_status && $(this).index() == 1)
    if(needLoad){return;}
    $("#rom_version_p").toggleClass("hidden");
    if($("#rom_version_p").is(":hidden") && $("#issue_rom_version").val() != ""){
      $("#issue_rom_version").val("");
      updateIssueFrom('/issues/new.js', $("#issue_rom_version")[0]);
    }
    $(".all-attributes").fadeOut(0).fadeIn(500);
  });

  $(".new_issue").on("change", "input.int_cf", function(){
    var is_case = $(this).siblings("label").text() == "关联Case"
    if(is_case && !isNaN($(this).val())){
      $.getJSON('/projects/' + ProjectIdentifier() + '/check_same_custom_value', {
        case_id: $(this).val(), custom_field_id: this.id.match(/\d+/)[0]
      }).done(function(result){
        if(!!result){
          var html = '<div class="window-wrapper"><div class="alert alert-warning">当前填写的关联Case在系统中已有如下记录，请确认不是重复后再继续创建。</div>'
          html += '<table class="issues list table table-striped table-bordered">'
          html += '<thead><tr><th>#</th><th>状态</th><th>主题</th><th>作者</th><th>创建时间</th></tr></thead><tbody>'
          $.each(result, function(k, v){
            html += '<tr><td class="id"><a href="/issues/' + v.id +'" target="_blank">' + v.id + '</a></td>'
            html += '<td>' + v.name + '</td>'
            html += '<td class="subject"><a href="/issues/' + v.id +'" target="_blank">' + v.subject + '</a></td>'
            html += '<td><a href="/users/' + v.author_id +'" target="_blank">' + v.firstname + '</a></td>'
            html += '<td>' + v.created_on.substring(0,10) + '</td></tr>'
          });
          html += '</tbody></table></div>'

          //Load Case ID repeat warning
          layer.open({
            type: 1,
            title: '<b>CaseID重复提醒</b>',
            area: ['1000px', 'auto'],
            zIndex: 666,
            moveType: 1,
            shadeClose: false,
            content: html
          });
        }
      });
    }
  })

  /////Issue Show and Edit page

  $(".status-history").click(function(){
    layer.open({
      type: 1,
      title: '<b>当前问题的历史状态</b>',
      area: ['500px', 'auto'],
      zIndex: 666,
      moveType: 1,
      shadeClose: false,
      content: $('.status-show-history')
    });
  })

  // Reverse Mokuai
  $("#reverseMokuai").on("click", function(){
    $.get("/projects/" + ProjectIdentifier() +"/mokuai_ownners/reverse",{ ownner: $("#issue_assigned_to_id").val()});
  });

  // Get DefaultValue template to Json
  $(".get-default-value").click(function(){
    this_cate = $(this).attr("for")
    $form = $(this).closest("form")
    $area = $form.find("#all_attributes")
    $object = $area.find("[name^='" + this_cate + "']")
    var json = {};
    $object.each(function(index, Element){
      name = $(Element).attr("name")
      value = $(Element).val()
      json[name] = value
    })

    // Add Project Identifer to Json
    json[this_cate + "[project_identifier]"] = ProjectIdentifier();

    default_value_window = layer.open({
      type: 1,
      title: '<b>保存模板</b>',
      area: ['400px', '180px'],
      zIndex: 666,
      moveType: 1,
      shadeClose: false,
      content: '<div class="window-wrapper" id="default-value-place"/>',
      btn: ['取消', '确定'],
      yes: function(index, layero){
        layer.close(default_value_window)
      },
      btn2: function(index, layero){
        // console.log(JSON.stringify(json))
        if($(".default_value_replace_menu").val() == "select") {
          $.post($(".window-select").val()
            ,{ _method: 'put', default_value: {json: JSON.stringify(json)} }
            ,function(result){
              layer.msg('更新成功！');
            })
            .fail(function() {
              alert( "更新失败！请确认你是否有权限！" );
              layer.close(default_value_window)
            })
        } else {
          var new_name = $(".window-input").val()
          if(new_name.replace(/\s/g,"") == "") {
            alert("文件名不可为空")
            return false
          }
          $.post("/default_values"
            ,{ default_value: {category: this_cate, name: new_name, json: JSON.stringify(json)} }
            ,function(result){
              layer.msg('保存成功！');
            })
            .fail(function() {
              alert( "创建失败！请确认你是否有权限！" );
              layer.close(default_value_window)
            })
        }
      }
    });
    // append conten to window wrapper
    var $dv_html = $("<div class='form-inline'/>");
    if($(".load-default-value").length > 0) {
      var $select = $("<select/>", {
        "class"  : "default_value_replace_menu form-control",
        "css" : {"margin-right" : "10px"},
        "change" : function(){
          $(this).siblings().hide();
          $(this).siblings($(this).val()).show();
        }
      });
      var $dv_input = $("<input/>", { "type" : "text", "class" : "window-input form-control" });
      var $dv_select = $("<select/>", { "class" : "window-select form-control", "css" : {"display" : "none"}});
      $select.append("<option value='input'>保存为新模板</option>", "<option value='select'>替换已有模板</option>");
      $(".load-default-value").each(function(){
        $("<option/>",{"value":$(this).find(".icon-right").attr("href"),"text":$(this).text()}).appendTo($dv_select)
      });
      $dv_html = $dv_html.append($select, $dv_input, $dv_select)
    } else {
      $dv_html = $dv_html.append(
        $("<label/>", { "text" : "请输入模板名称：", "css" : {"margin-right" : "10px"} }),
        $("<input/>", { "type" : "text", "class" : "window-input form-control" })
      );
    }
    $dv_html.appendTo($("#default-value-place"));
    $(".window-input").focus();
  });

  // Show dialog when issue set to REPEAT status
  $(document.body).on("change", "#issue_status_id", function(){
    if($(this).data("issues-id") == "null") {return;} // return if new issue
    if($(this).find(":selected").text() == "重复" && $(this).data("status-id") != $(this).val()) {
      $this = $(this);
      setTimeout(function(){ // delay 1 second
        if($this.find(":selected").text() != "重复") {return;} // return if current selected is not REPEAT
        var issue_id = $this.data("issue-id");
        var $dialog_html = $("<div class='window-wrapper'/>").append(
            $("<div/>", {"text": "在你将此问题置为重复的时候，我们需要记录所重复的ID，以便于后续跟踪。", "class": "alert alert-warning"})
              .append("<a target='_blank' href='/issues?search=issues.assigned_to_id+IN+(\"me\")&sort=updated_on:desc,id:desc'><strong>查看我的所有问题</strong></a>"),
            $("<label/>", {"text": "所以，本问题和谁重复："}),
            $("<input/>", {"type": "text", "class": "form-control", "placeholder": "问题ID", "id": "repeatIssueId"})

          );
        layer.open({
          type: 1,
          title: '<b>重复ID填写</b>',
          area: ['400px', '310px'],
          zIndex: 666,
          moveType: 1,
          shadeClose: false,
          content: $dialog_html[0].outerHTML,
          closeBtn: 0,
          btn: ['确定'],
          yes: function(index, layero){
            var repeat_issue_id = $("#repeatIssueId").val();
            if(/^\d+$/.test(repeat_issue_id)){
              $.post("/issues/" + issue_id + "/relations",{relation: {relation_type: 'duplicated', issue_to_id: repeat_issue_id}}, function(){layer.close(index)})
                .done(function() {layer.msg( "OK，已记录，请继续你之前的操作！" );})
            } else {
              layer.alert("输入的ID格式不规范，格式是数字哟！");
              return false;
            }
          }
        });
      }, 500)
    }
  })

  ///// Project Mokuai Ownner
  $("#issue-form").on("change", "select.mokuai-reason", function(){
    $.get("/projects/" + ProjectIdentifier() + "/mokuai_ownners/new",{ get: "reason", val: $(this).val()});
  })

  $(".mokuai_ownner_form").on("change", "select.mokuai-reason", function(){
    $.get("/projects/" + ProjectIdentifier() + "/mokuai_ownners/new",{ get: "reason", val: $(this).val(), from: 'all'});
  })

  $("#issue-form").on("change", "select.mokuai-name", function(){
    $.get("/projects/" + ProjectIdentifier() +"/mokuai_ownners/new",{ get: "name", val: $(this).val()});
  })



  function ProjectIdentifier(){
    var project_id;
    if($("#issue_project_id").length > 0)
      project_id = $("#issue_project_id option:selected").data("identifier")
    else
      project_id = location.pathname.split("/")[2]
    return project_id
  }

  // Edit Issue Related to issue
  $("#relation-issue-edit, #cancel-edit").click(function(){
    $(".relation-status span, .relation-status select, .relation-btn").map(function(){
      $(this).toggleClass("collapse")
    })
  })


  ///// User
  //Show user information pane
  var show_user_flag = true;
  $(document).on("mouseenter", "a[href^='/users/']", function(e){
    show_user_flag = true;
    user_match = this.href.match(/\d+$/);
    if(user_match){
      user_id = "#UserInfo-" + user_match[0]
      $user = $(user_id);
      if($user.length > 0) {
        if($user.is(":visible")) {return}
        setTimeout(function(){
          $(".user-info-pane").not($user[0]).fadeOut();
          $user.css({ left: e.pageX, top: e.pageY }).stop().fadeIn();
          if(!show_user_flag) {$user.hide();}
        }, 300);
      } else {
        $(this).addClass("ajax-loading");
        $.get(this.href).success(function(){
          setTimeout(function(){
            $(this).removeClass("ajax-loading");
            $(".user-info-pane").not($(user_id)[0]).fadeOut();
            $(user_id).css({ left: e.pageX, top: e.pageY }).fadeIn();
            if(!show_user_flag) {$(user_id).hide();}
          }, 300);
        });
      }
    }
  });

  $(document).on("mouseleave", "a[href^='/users/'], div.user-info-pane", function(e){
    show_user_flag = false;
    setTimeout(function(){
      if(!show_user_flag) {$(".user-info-pane").hide();}
    }, 300);
  });

  $(document).on("mouseenter", "div.user-info-pane", function(e){
    show_user_flag = true;
  });

  ////// Notification
  // Show or hide notification action
  $(".notification-list").on("click", ".notification-content, .notification-menu i", function(){
    var $li = $(this).closest("li"),
        $action = $li.find(".notification-acton"),
        $icon = $li.find(".notification-menu i")
    $action.stop(true, false).slideToggle("fast", function(){
      // Mark to read via ajax
      if($(this).is(':visible') && $(this).siblings(".notification-flag").hasClass('unread')){
        if($(this).attr('data-handle-read')){
          $.post($(this).data("handle-read"));
        }
      }
    });
    $icon.toggleClass("fa-chevron-down fa-chevron-up");
    $(".notification-acton").not($action[0]).slideUp("fast");
    $(".notification-menu i").not($icon[0]).removeClass("fa-chevron-up").addClass("fa-chevron-down");
  });

  ////// Project
  // Show different category content of project
  $("#all_attributes").on("change", "#project_category", function(){
    $.ajax({
      url: '/projects/new',
      type: 'post',
      data: $(this).closest("form").serialize()
    });
  })
  // Project quickly search
  $(".project-search > .search-box").on("input", function(){
    var val = $(this).val();
    var $root = $(".projects.root").children();
    var notice = '<p class="nodata">' + $(this).data("nodata") +'</p>'

    if(!val) {return false} // return if empty
    $root.show();

    $("#projects .project, #productions .project").unhighlight().highlight(val);
    if(val) { $root.not($root.has('.highlight')).hide(); }
    if(!$root.filter(':visible').length) {
      $root.first().before(notice);
    } else {
      $root.siblings(".nodata").remove();
    }
  })


  ///// Only Self Scroll
  $('.only_self_scroll').on('mouseenter', function(){
    var _self = $(window).scrollTop();
    $(window).on("scroll.onlySelfScroll", function(){ $(this).scrollTop(_self); });
  }).on('mouseleave', function(){
    $(window).off('scroll.onlySelfScroll');
  });


});
