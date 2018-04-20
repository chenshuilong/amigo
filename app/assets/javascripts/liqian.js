/**
 * LiQian's Javascript
 *
 * created_at 2017-05-09
 */

$(document).ready(function(){
  (function ($) {
    //Disabled version_as_increase_version when project_category is other
    var category= $("#project_category").val();
    var obj = $("select#as_increase_version");
    if(category === "other"){
      obj.prop("disabled", true);
    }else{
      obj.prop("disabled");
    }

    //Refresh specs when project_name changed
    $('.version_searchs #project_name').on('change', function (evt) {
      var name = $("#project_name").val();
      disabledSpec(name, category);
    });

    //Checked specs and projects
    $(".spec_compare_list .check-specs").on("click", function () {
      var spec_val = $(this).val();
      var check = $(this).prop('checked');
      var checked_list = getCheckList();

      if(check){
        if(checked_list.length > 5){
          layer.alert("最多比较5个不同规格!");
          return false;
        }else{
          $(this).prop("checked",true);
        }
      }else{
        $(this).prop("checked",false)
      }

      $("#current_check_count").html(checked_list.length);
    });

    $(".spec_compare_list #projects").on("change.select2", function(){
      var name = $(this).val();
      var current_type = $("#current_action").val();
      if(name == null){
        $("#specs").prop("disabled", true)
      }else{
        $.get("/specs/update_specs", {name: name, type: current_type})
      }
    })


    function disabledSpec(name, category){
      if(name == null){
        $(".version_searchs #spec").prop("disabled", true)
      }else{
        $.get("/versions/specs", {category: category, name: name})
      }
    }

    function getCheckList(){
      var checked =[];
      $('input[name="specs[]"]:checked').each(function(){
         checked.push($(this).val());
      });
      return checked
    }

    //version publish confirm to publish
    $("#version-publishes-index .publish, #version-publish-preview .publish").on("click", function(){
      var id = $(this).attr("data-id");
      // confirmVersionPublish(id);
      var html = '<form class="row form-horizontal" id="publish-form" style="margin:20px;padding-left:20px;width:580px">\
                    <div class="attributes">\
                      <div><strong> 1、官网公示信息标题：<strong/></div>\
                      <div class="input-group" style="margin-top: 20px; margin-left: 40px">\
                        <input type="text" class="form-control" name="xinghao" id="xinghao" placeholder="型号">\
                        <span class="input-group-addon">预置应用公示-</span>\
                        <input type="text" class="form-control" name="system_version" id="system_version" placeholder="系统版本">\
                      </div>\
                      <small class="form-text text-muted" style="margin-top: 10px; margin-left: 40px"> *在手机系统中，从设置->关于手机获取当前手机型号和系统版本信息</small>\
                      <br /> \
                      <div style="margin-bottom: 10px"><strong> 2、官网信息内容上传范围选择：<strong/></div>\
                      <div class="form-group">\
                          <label class="col-sm-3 control-label">应用中文名</label>\
                          <div class="col-sm-7"><input type="checkbox" name="title[cn_name]" id="title_cn_name" checked="checked" value="应用中文名"></div>\
                      </div>\
                      <div class="form-group">\
                          <label class="col-sm-3 control-label">桌面显示名称</label>\
                          <div class="col-sm-7"><input type="checkbox" name="title[desktop_name]" id="title_desktop_name" checked="checked" value="桌面显示名称"></div>\
                      </div>\
                      <div class="form-group">\
                          <label class="col-sm-3 control-label">功能描述</label>\
                          <div class="col-sm-7"><input type="checkbox" name="title[description]" id="title_description" checked="checked" value="功能描述"></div>\
                      </div>\
                      <div class="form-group">\
                          <label class="col-sm-3 control-label">开发者信息</label>\
                          <div class="col-sm-7"><input type="checkbox" name="title[developer]" id="title_developer" checked="checked" value="开发者信息"></div>\
                      </div>\
                      <div class="form-group">\
                          <label class="col-sm-3 control-label">版本号</label>\
                          <div class="col-sm-7"><input type="checkbox" name="title[version_name]" id="title_version_name" checked="checked" value="版本号"></div>\
                      </div>\
                      <div class="form-group">\
                          <label class="col-sm-3 control-label">权限</label>\
                          <div class="col-sm-7"><input type="checkbox" name="title[permission]" id="title_permission" checked="checked" value="权限"></div>\
                      </div>\
                      <div class="form-group">\
                          <label class="col-sm-3 control-label">是否可卸载</label>\
                          <div class="col-sm-7"><input type="checkbox" name="title[removable]" id="title_removable" checked="checked" value="是否可卸载"></div>\
                      </div>\
                    </div>\
                 </form>';
      layer.open({
        type: 1,
        title: '<b>上传官网</b>',
        area: ['800px', 'auto'],
        zIndex: 666,
        moveType: 1,
        shadeClose: false,
        content: html,
        btn: ['取消', '确定'],
        yes: function (index, layero) {
          layer.close(index)
        },
        btn2: function (index, layero) {
          var $checked = $("input[type=checkbox]:checked");
          var $xinghao = $("input#xinghao");
          var $systemVersion =$("input#system_version");
          if($xinghao.val() == null || $xinghao.val() == '' || $xinghao.val() == undefined){layer.alert('型号不能为空！'); return false;}
          if($systemVersion.val() == null || $systemVersion.val() == '' || $systemVersion.val() == undefined){layer.alert('系统版本不能为空！'); return false;}
          if($checked.length <= 0) {layer.alert('上传范围不能为空！'); return false;}
          location.href = '/version_publishes/' + id + '/publish?'+ $("form#publish-form").serialize();
        },
        success: function(){
        }
      });
    })

    // function confirmVersionPublish(id) {
    //   layer.confirm("是否需要同步最新消息？", {btn: ['取消', '确定']},
    //     function (cancal) {
    //       layer.close(cancal);
    //     },
    //     function () {
    //       location.href = '/version_publishes/' + id + '/publish'
    //     }
    //   );
    // }

    //version permission confirm to delete
    $("#versionPermissions .permission").on("click", function(){
      var id = $(this).attr("data-id");
      deleteVersionPermission(id);
    })

    function deleteVersionPermission(id) {
      layer.confirm("确定删除当前权限？", {btn: ['取消', '确定']},
        function (cancal) {
          layer.close(cancal);
        },
        function () {
          $.ajax({
            type: "DELETE",
            url: '/version_permissions/' + id,
            success: function(result){
              location.href = '/version_permissions'
            }
          });
        }
      );
    }

    //Recently visit project
    $(".expand-pad-button").click(function(){

      if($(".expand-pad-button i").hasClass("fa-angle-double-left")){
        $(".expand-pad-button i").removeClass("fa-angle-double-left").addClass("fa-angle-double-right");
        $("#bottomNotice").collapse('hide');
      } else {
        $(".expand-pad-button i").removeClass("fa-angle-double-right").addClass("fa-angle-double-left");
        $("#bottomNotice").collapse('show');
      }

      var $content, $pad;
      $pad = $(".expand-pad");
      $content = $(".expand-pad-content");

      var history = localStorage.getItem("projectsHistory");
      var results = []
      
      $.ajaxSetup({async:false});
      $.getJSON("/view_records/lists", function(result){
        results = result;
      }).fail(function(){
        results = [];
      })

      var data = results;
      var html = '';
      html = html + '<div class="panel panel-primary project-history-box">'
                        + '<div class="panel-heading">最近访问项目/产品</div>';

      html = html + '<div class="panel-body"><ul class="list-group" style="margin-bottom:0">';

      for (var i=0; i < data.length; i++) {
        if(i < 15){
          html += '<li class="list-group-item" style="padding: 5px 15px;border:0"><a onclick="_hmt.push([\'_trackEvent\', \'nav\', \'click\', \'最近访问项目/产品\'])" href="/projects/'+ data[i].identifier+'">' + data[i].name + '</a></li>';
        }
      }

      html = html + '</ul></div></div>'

      $content.html(html);
      $pad.toggleClass('expand-pad-active');
      return $content.toggleClass('expand-pad-content-active');
    });

    window.onload=function(){
      changeDivHeight();
    }
    window.onresize=function(){
      changeDivHeight();
    }
    function changeDivHeight(){
      var headHeight = $(".browser-notice").innerHeight() + $("nav.navbar").innerHeight() + $(".nav-content").innerHeight();
      var bodyHeight = $(window).innerHeight() - 2 * headHeight;
      $(".expand-pad").css({"height": bodyHeight, "top": headHeight,"display": "inline-flex"});
    }

    $("#repo_request_use").on("change", function(){
      $select = $(this);
      if($select.val() == 5){
        $("#repoStatus").hide();
      }else{
        $("#repoStatus").show();
      }
    })

    $(".repo_request_index #abandonRepoRequest").on("click", function(){
      var id = $(this).attr("data-id");
      var content1 = $(this).attr("data-content1");
      var content2 = $(this).attr("data-content2");
      abandonRepoRequest(id, content1, content2);
    })

    function abandonRepoRequest(id, c1, c2) {
      var content = "<div>";
      content = content + "<div>用途: " + c1 + "</div></br>";
      content = content + "<div>分支名: " + c2 + "</div></br>";
      content = content + "<div style='color: red;text-align: center'><strong>请确定上述分支流是否要废弃？</strong></div></br>"
      content = content + "</div>";
      layer.confirm(content, {btn: ['取消', '确定'], title: '重要提醒'},
        function (cancal) {
          layer.close(cancal);
        },
        function () {
          $.ajax({
            type: "GET",
            url: '/repo_requests/' + id+'/abandon',
            success: function(result){
              location.href = '/project_branch/repo_requests'
            }
          });
        }
      );
    }

    $("#googleToolTable .deleteGoogleTool").on("click", function(){
      var id = $(this).attr("data-id");
      var content1 = $(this).attr("data-content1");
      var content2 = $(this).attr("data-content2");
      var content3 = $(this).attr("data-content3");
      var content4 = $(this).attr("data-content4");
      var content5 = $(this).attr("data-content5");
      onDeleteGoogleTool(id, content1, content2, content3, content4, content5);
    })

    function onDeleteGoogleTool(id, c1, c2, c3, c4, c5) {
      var content = "<div>";
      content = content + "<div>" + c1 + ":" + c2 + "</div></br>";
      content = content + "<div>" + c3 + ":" + c4 + "</div></br>";
      content = content + "<div style='color: red;text-align: center'><strong>确定要删除该工具版本信息？</strong></div></br>"
      content = content + "</div>";
      layer.confirm(content, {btn: ['取消', '确定'], title: '删除提醒'},
        function (cancal) {
          layer.close(cancal);
        },
        function () {
          $.ajax({
            type: "DELETE",
            url: '/google_tools/' + id,
            success: function(result){
              location.href = '/google_tools/category?category='+c5;
            }
          });
        }
      );
    }

    $("#toolTable .deleteTool").on("click", function(){
      var id = $(this).attr("data-id");
      var content1 = $(this).attr("data-content1");
      onDeleteTool(id, content1);
    })

    function onDeleteTool(id, c1) {
      var content = "<div>";
      content = content + "<div style='text-align: center'>" + c1 + "</div></br>";
      content = content + "<div style='color: red;text-align: center'><strong>确定要删除该工具？</strong></div></br>"
      content = content + "</div>";
      layer.confirm(content, {btn: ['取消', '确定'], title: '删除提醒'},
        function (cancal) {
          layer.close(cancal);
        },
        function () {
          $.ajax({
            type: "DELETE",
            url: '/tools/' + id,
            success: function(result){
              location.href = '/tools';
            }
          });
        }
      );
    }

    $(".home-notification").on("click", function(){    
      if($(".notification-body").hasClass("in")){
        $(".expand-pad").removeClass('expand-pad-active');
        $(".expand-pad-button i").removeClass("fa-angle-double-right").addClass("fa-angle-double-left");
      }else{
        if($(".expand-pad-button i").hasClass("fa-angle-double-right")){
          $(".expand-pad").removeClass('expand-pad-active');
          $(".expand-pad-button i").removeClass("fa-angle-double-right").addClass("fa-angle-double-left");
        }
      }
    })

  })(jQuery);
});

function deleteApkBase(projectId, id) {
  var remoteUrl = "/projects/" + projectId.toString() + '/apk_bases/' + id.toString();
  
  layer.confirm("确定删除该APK基本信息？", {btn: ['取消', '确定']},
    function (cancal) {
      layer.close(cancal);
    },
    function () {
      remote(remoteUrl, "DELETE", {}, function (res) {
        location.href =  "/projects/" + res.project.toString() + '/apks';
      });
    }
  );
}

function generatePatchNo(url, el) {
  var url = "/patches/new";
  var data = $(".newPatchForm").serialize()+"&format=js";
  $.get(url, data);
}

function submitByValidate(){
    var patch_type = $("#patch_patch_type");
    var notes = $("#patch_notes");
    var mani_url = $("#patch_init_command_manifest_url");
    var mani_branch = $("#patch_init_command_manifest_branch");
    var mani_xml = $("#patch_init_command_manifest_xml");
    var object_ids = $("#patch_object_ids");
    var proprietary_tag = $("#patch_proprietary_tag");
    var due_at = $("#patch_due_at");

    var content;
    if(notes.val() == ""){
      layer.msg("描述 必填");
      return false;
    }else if(mani_url.val() == ""){
      layer.msg("manifest_url 必填");
      return false;
    }else if(mani_branch.val() == ""){
      layer.msg("manifest_branch 必填");
      return false;
    }else if(patch_type.val() == "2" && proprietary_tag.val() == ""){
      layer.msg("ProprietaryTag 必填");
      return false;
    }else if(object_ids.val() == null){
      layer.msg("待验证项目 必填");
      return false;
    }else if(due_at.val() == ""){
      layer.msg("计划完成日期 必填");
      return false;
    }else{
      $("form#new_patch").submit();
    }
  };

function versionChangeInfos() {
  var url = $(".editVersionForm").attr("action")+"/edit";
  var data = $(".editVersionForm").serialize()+"&format=js";
  $.get(url, data);
}

function apkBaseChangeInfos(url) {
  var data = $(".apkBaseForm").serialize()+"&format=js";
  $.get(url, data);
}

function showRemoteUrl(title, items){
  var content = "<div>";
  for(i=0; i < items.length; i++){
    content = content + "<span><a href='"+items[i].url+"'> " + items[i].name + "</a></span></br>";
  }
  content = content + "</div>";
  layer.confirm(content, {btn: [], title: title+"工具列表"},
    function (cancal) {
      layer.close(cancal);
    }
  );
}

function editTableInfo(id, bool, info){
  if(!bool){
    return false;
  }
  var all_input = $("#okrsEditTable input");
  var all_input_len = all_input.length;
  for(i=0; i< all_input_len;i++){
    var ipt = all_input[i];
    var ipt_obj = $('#'+ipt.id);
    var ipt_data_id = ipt_obj.data('id');
    var ipt_value = ipt_obj.val();
    var ipt_td_id = "td#result-"+info+"-"+ipt_data_id
    var ipt_td = $(ipt_td_id);
    var check_data = isPositiveNum(ipt_obj);
    if(check_data == false){
      ipt_td.children().remove();
      ipt_td.val('');
    }else{
      clearTableInfo(ipt_td, ipt_value);
      toSaveScore(ipt_obj);
    };
  }
  var obj = $("td#result-"+info+"-"+id);
  if(obj.children("div").length == 0){
    var current_value = obj.html();
    obj.html('');
    var div = document.createElement('div')
    var span = document.createElement('span')
    var input = document.createElement('input');
    input.setAttribute('type', 'text');
    input.setAttribute('name', 'key_result['+id+']')
    input.setAttribute('data-id', id);
    input.setAttribute('value', current_value);
    input.setAttribute('id', 'okr-key-result-input-'+id+'');
    input.style.width = "60%";
    div.appendChild(input);
    div.appendChild(span);
    obj[0].appendChild(div);
    obj.unbind("click");
    input.focus();
  }else{
    return false;
  }
}

function toSaveScore(obj){
  var id = obj.data("id");
  var data = obj.val();
  var ipt_td = obj.parent().parent();
  var check_data = isPositiveNum(obj);
  if(check_data == true){
    $.ajax({
      type: "GET",
      url: '/okrs/score?id='+id+'&data='+data,
      success: function(result){
        if(result.status == true){
          window.location.reload();
        }else{
          clearTableInfo(ipt_td, data);
        }
      }
    });
  }else{
    obj.focus();
  }
}

function clearTableInfo(obj, value){
  obj.children().remove();
  obj.html(value);
}

$(document).on("blur", "#okrsEditTable input", function(){
  toSaveScore($(this));
});

$(document).on("click", ".result_score", function(){
  if($(this).children("div").length == 0){
    var id = $(this).data('id');
    var bool = $(this).data('bool');
    var info = $(this).data('info')
    editTableInfo(id, bool, info);
  }else{
    return false;
  };
})

function isPositiveNum(obj){
  var num = obj.val();
  var result = true;
  if(isNaN(num)) {layer.msg("请输入0-10之内的数字！"); result=false;}
  if(num < 0 || num > 10){ layer.msg("请输入0-10之内的数字！"); result=false} 
  return result
}

$(document).on("click", ".check_all", function(){
   var category = $(this).data("category");
   var selector = $("table#"+category+"OkrTable");
   var isChecked = $(this).prop("checked");
   selector.find("tbody :checkbox").prop("checked", isChecked);
})

$(document).on("click", "#export_okrs", function(){
  var $ipts = $("table tbody input:checked");
  var ids = [];
  $ipts.each(function(){
    ids.push($(this).val());
  });
  location.href = "/okrs/export?format=pdf&ids="+ids;
})

$(document).on("click", "#recall_okrs", function(){
  var $ipts = $("table tbody input:checked");
  var ids = [];
  $ipts.each(function(){
    ids.push($(this).val());
  });
  $.ajax({
    type: "GET",
    url: "/okrs/recall?format=js&ids="+ids,
    success: function(result){
      layer.msg(result.message);
      if(result.status == true){location.href = "/okrs/my"}
    }
  });
})

$(function () { 
  $("#okr_desc").popover({html: true});
});