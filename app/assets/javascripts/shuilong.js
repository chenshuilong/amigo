/**
 * Created by csl on 16-9-5.
 */

// -----------------------------------------------------------------------
//
// Printing plug-in for jQuery, evolution of jPrintArea: http://plugins.jquery.com/project/jPrintArea
//
//------------------------------------------------------------------------

(function ($) {
    var opt;

    $.fn.jqprint = function (options) {
        opt = $.extend({}, $.fn.jqprint.defaults, options);
        var $element = (this instanceof jQuery) ? this : $(this);

        if (opt.operaSupport && $.browser.opera) {
            var tab = window.open("", "jqPrint-preview");
            tab.document.open();
            var doc = tab.document;
        }
        else {
            var $iframe = $("<iframe  />");
            if (!opt.debug) {
                $iframe.css({position: "absolute", width: "0px", height: "0px", left: "-600px", top: "-600px"});
            }
            $iframe.appendTo("body");
            var doc = $iframe[0].contentWindow.document;
        }

        if (opt.importCSS) {
            if ($("link[media=print]").length > 0) {
                $("link[media=print]").each(function () {
                    doc.write("<link type='text/css' rel='stylesheet' href='" + $(this).attr("href") + "' media='print' />");
                });
            }
            else {
                $("link").each(function () {
                    doc.write("<link type='text/css' rel='stylesheet' href='" + $(this).attr("href") + "' />");
                });
            }
        }

        if (opt.printContainer) {
            doc.write($element.outer());
        }
        else {
            $element.each(function () {
                doc.write($(this).html());
            });
        }

        doc.close();

        (opt.operaSupport && $.browser.opera ? tab : $iframe[0].contentWindow).focus();
        setTimeout(function () {
            (opt.operaSupport && $.browser.opera ? tab : $iframe[0].contentWindow).print();
            if (tab) {
                tab.close();
            }
        }, 1000);
    }

    $.fn.jqprint.defaults = {
        debug: false,
        importCSS: true,
        printContainer: true,
        operaSupport: true
    };

    jQuery.fn.outer = function () {
        return $($('<div></div>').html(this.clone())).html();
    }
})(jQuery);

// ----------------------------------------------------------------------
// <summary>
// 限制只能输入数字
// </summary>
// ----------------------------------------------------------------------
$.fn.onlyNum = function () {
    $(this).keypress(function (event) {
        var eventObj = event || e;
        var keyCode = eventObj.keyCode || eventObj.which;
        if ((keyCode >= 48 && keyCode <= 57))
            return true;
        else
            return false;
    }).focus(function () {
        //禁用输入法
        this.style.imeMode = 'disabled';
    }).bind("paste", function () {
        //获取剪切板的内容
        var clipboard = window.clipboardData.getData("Text");
        if (/^\d+$/.test(clipboard))
            return true;
        else
            return false;
    });
};

// ----------------------------------------------------------------------
// <summary>
// 限制只能输入字母
// </summary>
// ----------------------------------------------------------------------
$.fn.onlyAlpha = function () {
    $(this).keypress(function (event) {
        var eventObj = event || e;
        var keyCode = eventObj.keyCode || eventObj.which;
        if ((keyCode >= 65 && keyCode <= 90) || (keyCode >= 97 && keyCode <= 122))
            return true;
        else
            return false;
    }).focus(function () {
        this.style.imeMode = 'disabled';
    }).bind("paste", function () {
        var clipboard = window.clipboardData.getData("Text");
        if (/^[a-zA-Z]+$/.test(clipboard))
            return true;
        else
            return false;
    });
};

// ----------------------------------------------------------------------
// <summary>
// 限制只能输入数字和字母
// </summary>
// ----------------------------------------------------------------------
$.fn.onlyNumAlpha = function () {
    $(this).keypress(function (event) {
        var eventObj = event || e;
        var keyCode = eventObj.keyCode || eventObj.which;
        if ((keyCode >= 48 && keyCode <= 57) || (keyCode >= 65 && keyCode <= 90) || (keyCode >= 97 && keyCode <= 122))
            return true;
        else
            return false;
    }).focus(function () {
        this.style.imeMode = 'disabled';
    }).bind("paste", function () {
        var clipboard = window.clipboardData.getData("Text");
        if (/^(\d|[a-zA-Z])+$/.test(clipboard))
            return true;
        else
            return false;
    });
};

// ----------------------------------------------------------------------
// <summary>
// 序列化对象
// </summary>
// ----------------------------------------------------------------------
$.prototype.serializeObject = function () {
    var obj = new Object();
    $.each(this.serializeArray(), function (index, param) {
        if (!(param.name in obj)) {
            obj[param.name] = param.value;
        } else {
            obj[param.name] += "," + param.value;
        }
    });
    return obj;
};

// ----------------------------------------------------------------------
// <summary>
// toolTip
// </summary>
// ----------------------------------------------------------------------
$.fn.showToolTip = function (content) {
    var dialogLayer;
    $(this).mouseenter(function () {
        dialogLayer = layer.tips(content, this);
    })

    $(this).mouseleave(function () {
        if(dialogLayer)
            layer.close(dialogLayer);
    })
};

// ----------------------------------------------------------------------
// <summary>
// make the windows fullScreen
// </summary>
// ----------------------------------------------------------------------
$.fn.fullScreenWindow = function () {
    $(this).fullScreen();
    e.preventDefault();
}

// ----------------------------------------------------------------------
// <summary>
// multiple rows selection
// </summary>
// ----------------------------------------------------------------------
$.fn.selectionRows = function (content) {
    $(this).find("tbody").on( 'click', 'tr', function () {
        $(this).toggleClass('selected');
    });
};

$.fn.disabledControl = function(){
    $(this).attr("disabled", "disabled");
}

$.fn.enabledControl = function(){
    $(this).removeAttr("disabled");
}

$.fn.choose_remote = function(arg) {
    var arg = arg || {};
    var holder = arg.holder || "--- 请选择 ---";
    var url = arg.url || "/users/assigned";
    var clear = this[0].hasAttribute("multiple") ? false : true;
    var option_text = arg.text || "name";
    this.addClass("ajax-loading");
    if (url.length > 0){
        this.select2({
            allowClear: clear,
            placeholder: holder,
            ajax: {
                url: url,
                type: arg.type || 'GET',
                dataType: "json",
                delay: 250,
                data: function(params){
                    var para = {name: params.term, page: params.page};
                    $.each(arg.data, function( key, value ) {
                        eval("para." + key.toString() + " = " + value.toString())
                    });
                    return para;
                },
                cache: true,
                processResults:  function (result, params) {
                    var options = [];
                    $.each(result, function(i, v){
                        var option = {"id": v.id, "text": eval("v." + option_text)};
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
    } else {
        layer.msg("无效的参数!")
    }
};

function openLayer(title, width, content, okFunc) {
    dialog = layer.open({
        type: 1,
        title: '<b>' + title + '</b>',
        area: [width, 'auto'],
        zIndex: 666,
        moveType: 1,
        shadeClose: false,
        content: content,
        btn: ['取消', '确定'],
        yes: function (index, layero) {
            layer.close(dialog)
        },
        btn2: okFunc
    });
}

function openLayerWithoutBtns(title, width, content) {
    dialog = layer.open({
        type: 1,
        title: '<b>' + title + '</b>',
        area: [width, 'auto'],
        zIndex: 666,
        moveType: 1,
        shadeClose: false,
        content: content
    });
}

function openConfirmDiaiog(title, okFunc) {
    var content = title || "确定要执行此操作吗？";
    layer.confirm(content, {btn: ['取消', '确定']},
        function (cancal) {
            layer.close(cancal);
        },
        okFunc
    );
}

function msgBox(content) {
    var box = layer.open({
        type: 1,
        title: '提示',
        area: ['400px', 'auto'],
        zIndex: 999,
        moveType: 1,
        shadeClose: false,
        content: content,
        btn: ['关闭'],
        yes: function (index, layero) {
            layer.close(box);
        }
    });

    return box;
}

function timeoutMsgBox(time, content) {
    var box = msgBox('<p style="text-align: center;">' + content + '</p>');

    setTimeout(function () {
        layer.close(box);
    }, time);
}

function linkageDatePicker(beginSelector, endSelector) {
    $(beginSelector).attr('type', 'text').datetimepicker(
        {
            lang: 'ch',
            autoclose: true,
            startView: 0,
            format: "Y-m-d",
            clearBtn: true,
            todayBtn: true,
            endDate: new Date()
        }).on('changeDate', function (ev) {
        if (ev.date) {
            $(endSelector).datetimepicker('setStartDate', new Date(ev.date.valueOf()))
        } else {
            $(endSelector).datetimepicker('setStartDate', null);
        }
    })

    $(endSelector).attr('type', 'text').datetimepicker(
        {
            lang: 'ch',
            autoclose: true,
            startView: 0,
            format: "Y-m-d",
            clearBtn: true,
            todayBtn: true,
            endDate: new Date()
        }).on('changeDate', function (ev) {
        if (ev.date) {
            $(beginSelector).datetimepicker('setEndDate', new Date(ev.date.valueOf()))
        } else {
            $(beginSelector).datetimepicker('setEndDate', new Date());
        }

    })
}

function initDateTimePicker(id, timeFormat, timepicker) {
    var time = currentDate(timepicker);

    $('#' + id.toString()).attr('type', 'text').datetimepicker({
        format: timepicker ? 'Y-m-d H:i:s' : timeFormat, lang: 'ch',
        todayBtn: true, startDate: time, initialDate: time,
        timepicker: timepicker, scrollInput: false
    });
}

function remote(remoteUrl, remoteType, remoteData, succFunc) {
    $(".ajax-loading").removeClass("ajax-loading");

    $.ajax({
        url: remoteUrl,
        type: remoteType,
        data: remoteData,
        dataType: "json",
        success: succFunc,
        error: function (jqXHR, textStatus, errorThrown) {
            timeoutMsgBox(5000, jqXHR.responseText);
        }
    });
}

function changReportData(pId, tableId) {
    var postdata = new Object();
    postdata.id = parseInt(pId);
    postdata.type = tableId;
    if (getQueryString("condition_id") != null)
        postdata.condition_id = getQueryString("condition_id");
    if (window.location.toString().indexOf("more") > -1)
        postdata.more = true;

    remote("/reports/display_reports", "POST", postdata, function (data) {
        if (data.rows != null || data.rows != undefined) {
            var rows = "<thead><tr><td>排名</td>";
            if (tableId.indexOf("personal") > -1) {
                rows += "<td>姓名</td>";
            } else {
                rows += "<td>部门</td>";
            }
            // rows += "<td>" + (tableId.indexOf("unsolved") > -1 ? "遗留" : "解决") + "时长</td></tr></thead>";
            rows += "<td>时长(H)</td></tr></thead>";
            $.each(data.rows, function (index, item) {
                rows += "<tbody><tr><td>" + (index + 1).toString() + "</td>";
                if (tableId.indexOf("personal") > -1) {
                    rows += "<td>" + item.assigoedname + "</td>";
                } else {
                    rows += "<td>" + item.orgNm + "</td>";
                }
                rows += "<td>" + item.solved_times + "</td></tr>"
            });
            rows += "</tbody>";

            $("#" + tableId.toString()).empty().append(rows);
        }
    });
}

function reload() {
    var opts = "";
    var searchName = $('#search').val();
    if ($.trim(searchName).length > 0) {
        remote("/users/search?name=" + $.trim(searchName), "GET", {}, function (data) {
            if (data != null && data != undefined) {
                $.each(data, function (idx, item) {
                    opts += "<option value=\" " + item.id.toString() + "\">" + item.name.toString() + "</option>";
                });
            }
        });
    }
    $('#search').empty().append(opts);
    $('#search').selectpicker("refresh");
    $('#search').empty().append("show");
}

function disabledControl(cId) {
    $("#" + cId).attr("disabled", "disabled");
}

function enabledControl(cId) {
    $("#" + cId).removeAttr("disabled");
}

function getQueryString(name) {
    var reg = new RegExp("(^|&)" + name + "=([^&]*)(&|$)", "i");
    var r = window.location.search.substr(1).match(reg);
    if (r != null) return unescape(r[2]);
    return null;
}

function getQueryStringFromUrl(url, name) {
    var reg = new RegExp("(^|&)" + name + "=([^&]*)(&|$)", "i");
    var r = url.substr(1).match(reg);
    if (r != null) return unescape(r[2]);
    return null;
}

function getFormParams(formObj) {
    var allStr = "";
    if (formObj) {
        var elementsObj = formObj.elements;
        var obj;
        if (elementsObj) {
            for (var i = 0; i < elementsObj.length; i += 1) {
                obj = elementsObj[i];
                if (obj.name != undefined && obj.name != "") {
                    allStr += "&" + obj.name + "=" + encodeURIComponent(obj.value);
                }
            }
        } else {
            //alert("没有elements对象!");
            return;
        }
    } else {
        //alert("form不存在!");
        return;
    }

    return allStr;
}

function formToString(formObj) {
    var allStr = "";
    if (formObj) {
        var elementsObj = formObj.elements;
        var obj;
        if (elementsObj) {
            for (var i = 0; i < elementsObj.length; i += 1) {
                obj = elementsObj[i];
                if (obj.name != undefined && obj.name != "") {
                    if ($.inArray(obj.name.toString(), ["role_value", "project_value", "probability", "priority_id",
                            "project_ids", "status_ids", "assigned_dept_ids", "assigned_to_ids"]) != -1) {
                        allStr += "&" + obj.name + "=" + encodeURIComponent($("#" + obj.name.toString()).val());
                    } else {
                        allStr += "&" + obj.name + "=" + encodeURIComponent(obj.value);
                    }
                }
            }
        } else {
            //alert("没有elements对象!");
            return;
        }
    } else {
        //alert("form不存在!");
        return;
    }

    return allStr;
}

function initSelect(id) {
    $("#" + id.toString()).select2({
        placeholder: "请选择对应值", tokenSeparators: [',', ' ']
    });
}

function generateChart(chartId, title, subtitle, toolTipFormat, axisLabelFormat, legendData, xAxis, yAxisData, dataZoomYn, series) {
    var myChart = echarts.init(document.getElementById(chartId), 'infographic');
    // myChart.showLoading();

    var option = {
        title: {
            shadowColor: 'rgba(0, 0, 0, 0.5)',
            shadowBlur: 10,
            text: title,
            subtext: subtitle,
            x: "left"
        },
        tooltip: {
            padding: 5,
            backgroundColor: '#222',
            borderColor: '#777',
            borderWidth: 1,
            formatter: toolTipFormat
        },
        legend: {
            show: true,
            padding: 30,
            data: legendData
        },
        grid: {
            left: '30',
            right: '20',
            bottom: '30',
            containLabel: true
        },
        toolbox: {
            show: true,
            orient: 'vertical',
            left: 'right',
            top: 'middle',
            feature: {
                dataZoom: {
                    yAxisIndex: 'none'
                },
                magicType: {show: true, type: ['line', 'bar']},
                //brush: {show: true, type: ['rect', 'polygon', 'lineX', 'lineY', 'keep', 'clear']},
                dataView: {readOnly: false},
                restore: {},
                saveAsImage: {show: true},
                // myTool2: {
                //     show: true,
                //     title: '排序',
                //     icon: 'image://http://echarts.baidu.com/images/favicon.png',
                //     onclick: function (){
                //         preview();
                //         layer.msg("排序");
                //     }
                // }
            }
        },
        xAxis: xAxis,
        yAxis: {
            type: 'value',
            name: '',
            nameTextStyle: {
                color: '#ccc',
                fontSize: 18
            },
            axisLine: {
                lineStyle: {
                    color: '#ccc'
                }
            },
            splitLine: {
                show: true
            },
            axisLabel: {
                formatter: axisLabelFormat
            }
        },
        dataZoom: dataZoomYn ? [
            {
                type: 'slider',
                show: true,
                realtime: true,
                start: 0,
                end: 100,
                top: 25
            },
            {
                type: 'inside',
                realtime: true,
                start: 0,
                end: 100
            }] : [],
        series: series
    };

    myChart.setOption(option);
    // myChart.hideLoading();
}

function generateChartByGroup(title, legendData, xAxisData, dataZoomYn, series) {
    var myChart = echarts.init(document.getElementById("gioneeChart"), 'infographic');

    var option = {
        title: {
            text: title
        },
        tooltip: {
            trigger: 'axis'
        },
        legend: {
            show: true,
            padding: 30,
            data: legendData
        },
        grid: {
            left: '30',
            right: '20',
            bottom: '30',
            containLabel: true
        },
        toolbox: {
            show: true,
            orient: 'vertical',
            left: 'right',
            top: 'middle',
            feature: {
                dataZoom: {
                    yAxisIndex: 'none'
                },
                magicType: {show: true, type: ['line', 'bar']},
                //brush: {show: true, type: ['rect', 'polygon', 'lineX', 'lineY', 'keep', 'clear']},
                dataView: {readOnly: false},
                restore: {},
                saveAsImage: {show: true}
            }
        },
        xAxis: {
            type: 'category',
            boundaryGap: true,
            data: xAxisData,
            axisLabel: {
                interval: 0,
                show: true,
                rotate: -45
            }
        },
        yAxis: {
            type: 'value'
        },
        dataZoom: dataZoomYn ? [
            {
                type: 'slider',
                show: true,
                realtime: true,
                start: 0,
                end: 100,
                top: 25
            },
            {
                type: 'inside',
                realtime: true,
                start: 0,
                end: 100
            }] : [],
        series: series
    };

    myChart.setOption(option);
}

//preview button
function preview() {
    try {
        var sumAmount = 0;
        var form = $('#filterform');
        var report_name = $('#reportname').val().trim() + $('#reporttype').val();

        if ($('#reportname').val().trim().length == 0) {
            timeoutMsgBox(1500, "名称不能为空");
        } else {
            if ($.trim($('#role_value').val()).length == 0 && $.trim($('#project_value').val()).length == 0) {
                timeoutMsgBox(1500, "角色或者项目不能同时为空");
                return;
            }

            if (checkboxStatus("dwm_yn")) {
                var start_dt = Date.parse($('#start_dt').val());
                var end_dt = Date.parse($('#end_dt').val());

                if ($('#start_dt').val().trim().length > 0 && $('#end_dt').val().trim().length > 0) {
                    if (start_dt > end_dt) {
                        timeoutMsgBox("结束时间不能小于开始时间", 1500);
                        return;
                    }
                    if (start_dt > new Date().now) {
                        timeoutMsgBox("开始时间不能大于当前时间", 1500);
                        return;
                    }
                } else {
                    timeoutMsgBox("开始时间,结束时间不能为空");
                    return;
                }
            }

            remote("preview?cur_page=1&" + formToString(form.get(0)) + (checkboxStatus('dwm_yn') ? "&dwm_yn=1&created_time_yn=true" : "&dwm_yn=0"), "POST", {}, function (data) {
                if (data.table != null || data.table != undefined) {
                    $('#nav_report_name').empty().append(report_name);
                    $('#table_report_name').empty().append(report_name);
                    $('.autoscroll').empty().append(data.table);

                    var legendData = [];
                    var dataZoomYn = true;
                    var series = [];
                    var xAxis = {};
                    xAxis.axisLabel = {
                        show: true,
                        interval: 0,
                        rotate: -45,
                        margin: 5
                    };
                    xAxis.data = [];

                    if (checkboxStatus("dwm_yn")) {
                        var xAxisData = data.days.map(function (day, index) {
                            if ($('#day_week_month').find("option:selected").text() == "周")
                                return day + "周";
                            else
                                return day;
                        });

                        $.each(data.rows, function (idx, row) {

                            var seriesData = [];
                            series[idx] = {};
                            series[idx].type = "line";
                            series[idx].markLine = {
                                silent: true,
                                data: [
                                    {type: 'average', name: '平均值'}
                                ]
                            };

                            series[idx].label = {
                                normal: {
                                    show: true,
                                    position: 'top'
                                }
                            };

                            switch ($('#groupby').val()) {
                                case "issues.assigned_to_id":
                                    series[idx].name = row.username;
                                    legendData.push(row.username);
                                    break;
                                case "users.orgNm":
                                    series[idx].name = row.deptname;
                                    legendData.push(row.deptname);
                                    break;
                                case "issues.project_id":
                                    series[idx].name = row.projectname;
                                    legendData.push(row.projectname);
                                    break;
                                case "issues.mokuai_name":
                                    series[idx].name = row.mokuai_name;
                                    legendData.push(row.mokuai_name);
                                    break;
                                case "issues.mokuai_reason":
                                    series[idx].name = row.mokuai_reason;
                                    legendData.push(row.mokuai_reason);
                                    break;
                                default:
                                    series[idx].name = row.username;
                                    legendData.push(row.username);
                                    break;
                            }

                            $.each(data.days, function (index, item) {
                                switch ($('#day_week_month').val().toString()) {
                                    case "day":
                                        seriesData.push(row["d_" + item.toString()]);
                                        break;
                                    case "week":
                                        seriesData.push(row["w_" + item.toString()]);
                                        break;
                                    case "month":
                                        seriesData.push(row["m_" + item.toString()]);
                                        break;
                                }
                            });

                            sumAmount += Enumerable.From(seriesData).Sum();
                            series[idx].data = seriesData;
                        });

                        generateChartByGroup(report_name, legendData, xAxisData, dataZoomYn, series)
                    } else {
                        series[0] = {};
                        series[0].name = $('#reportname').val();
                        series[0].type = $('#charttype').val();
                        series[0].data = [];
                        xAxis.data = [];

                        Enumerable.From(data.rows).GroupBy("$.deptname").ForEach(function (rows, idx) {

                            Enumerable.From(rows).ForEach(function (item, index) {
                                switch ($('#groupby').val()) {
                                    case "issues.assigned_to_id":
                                        legendData.push(rows.source[0].username);
                                        xAxis.data.push(item.username);
                                        break;
                                    case "users.orgNm":
                                        legendData.push(rows.source[0].deptname);
                                        xAxis.data.push(item.deptname);
                                        break;
                                    case "issues.project_id":
                                        legendData.push(rows.source[0].projectname);
                                        xAxis.data.push(item.projectname);
                                        break;
                                    case "issues.mokuai_name":
                                        legendData.push(rows.source[0].mokuai_name);
                                        xAxis.data.push(item.mokuai_name);
                                        break;
                                    case "issues.mokuai_reason":
                                        legendData.push(rows.source[0].mokuai_reason);
                                        xAxis.data.push(item.mokuai_reason);
                                        break;
                                    default:
                                        legendData.push(rows.source[0].username);
                                        xAxis.data.push(item.username);
                                        break;
                                }

                                var value = item.amount;
                                if ($('#reporttype').val().indexOf("数量") > -1) {
                                    value = value == null ? 0 : value;
                                    sumAmount += parseFloat(value);
                                } else if ($('#reporttype').val().indexOf("时长") > -1) {
                                    value = value == null ? 0 : (value.toString().indexOf('天') <= -1 ? value : (
                                        parseFloat(value.substring(0, value.indexOf('天'))) * 24 * 3600 +
                                        parseFloat(value.substring(value.indexOf('天') + 1, value.indexOf('时'))) * 3600 +
                                        parseFloat(value.substring(value.indexOf('时') + 1, value.indexOf('分'))) * 60 +
                                        parseFloat(value.substring(value.indexOf('分') + 1, value.indexOf('秒')))
                                    ));
                                } else if ($('#reporttype').val().indexOf("率") > -1) {
                                    value = value == null ? 0 : parseFloat(value.toString().replace('%', ''));
                                }

                                series[0].data.push(value);
                                series[0].markPoint = {
                                    data: [
                                        {type: 'max', name: '最大值'},
                                        {type: 'min', name: '最小值'}
                                    ]
                                };
                                series[0].markLine = {
                                    silent: true,
                                    data: [
                                        {type: 'average', name: '平均值'}
                                    ]
                                };
                                if ($('#charttype').val() == "bar") {
                                    series[0].label = {
                                        normal: {
                                            show: true,
                                            position: 'top'
                                        }
                                    };
                                } else {
                                    series[0].label = {
                                        normal: {
                                            show: true,
                                            position: 'top'
                                        }
                                    };
                                }
                            });
                        });

                        generateChart("gioneeChart", report_name + "(" + sumAmount + ")", "", toolTipFormat, axisLabelFormat, legendData, xAxis, [], dataZoomYn, series);
                    }
                }
            });
        }
    } catch (e) {
        console.log(e)
    }
}

//export button
function export_data() {
    exportFromIrl("export?1=1" + formToString($('#filterform').get(0)));
}

function exportPersonalize(menuid, formId) {
    exportFromIrl("/reports/personalize_export_data?menuid=" + menuid + "&"
        + formToString($('#' + formId.toString()).get(0)));
}

function exportFromIrl(url) {
    window.open(url);
}

//Save button
function save() {
    if ($('#reportname').val().trim().length == 0) {
        timeoutMsgBox(1500, "名称不能为空");
        return;
    } else {
        if ($.trim($('#role_value').val()).length == 0 && $.trim($('#project_value').val()).length == 0) {
            timeoutMsgBox(1500, "角色或者项目不能同时为空");
            return;
        }
    }

    var report_name = $('#reportname').val().trim().replace("/", "") + "/" + $('#reporttype').val();
    $.post("/conditions/" + getQueryString("condition_id")
        , {
            _method: 'put',
            keep_update: true,
            condition: {
                name: report_name,
                json: JSON.stringify(getQueryConditions()),
                report_conditions: JSON.stringify(getReportCondition())
            }
        }
        , function (result) {
            refreshPage();
        })
        .fail(function () {
            timeoutMsgBox(1500, "保存失败！请确认你是否有权限！");
        });
}

function onDetails(ids) {
    exportFromIrl("/issues?search=issues.id in (" + ids + ")")
    // timeoutMsgBox(2000,"本功能暂未上线，敬请期待！");
}

function onPaginate(total, perPage, curPage) {
    remote("preview?total=" + total + "&per_page=" + perPage + "&cur_page=" + curPage +
        "&dwm_yn=" + (checkboxStatus("dwm_yn") ? 1 : 0).toString() + "&" + formToString($('#filterform').get(0)), "POST", {}, function (data) {
        $('.autoscroll').empty().append(data.table);
    });
}

function onGenerateCondition(btnDetail, isSum, ids, username, deptname, projectname, uId, dId, pId, assgId, cons) {
    var selected_first = $("#role_value").find("option:selected:first").text();
    var selected_last = $("#role_value").find("option:selected:last").text();

    var report_name = $('#reportname').val().trim() + $('#reporttype').val();
    if ($('#role').val() == "assigned_to_id")
        report_name = (isSum ? ($.trim(selected_first) == "" ? "所有" : (selected_first == selected_last ? selected_first : selected_first + "等")) : username) + "的" + $('#reporttype').val();
    else
        report_name = (isSum ? ($.trim(selected_first) == "" ? "所有" : (selected_first == selected_last ? selected_first : selected_first + "等")) : deptname) + "的" + $('#reporttype').val();

    cons.push(["AND", "by_tester", " = ", "1"]);
    var role = [], project = [], probability = [], priority_id = [];
    if ($("#role_value").val() != null && $("#role_value").val().toString() != "") {
        if ($("#role").val().toString() == "depts.id") {
            role.push("AND");
            role.push("dept_id");
            role.push(" = ");
            role.push($("#role_value").val().toString().split(","));
            cons.push(role);
        } else {
            if ($('#reporttype').val() != "发现bug数量") {
                role.push("AND");
                role.push($("#role").val().toString());
                role.push(" = ");
                role.push($("#role_value").val().toString().split(","));
                cons.push(role);
            }
        }
    }

    if ($("#project").val().toString() == "project_id" && $("#project_value").val() != null && $("#project_value").val().toString() != "") {
        project.push("AND");
        project.push("project_id");
        project.push(" = ");
        project.push($("#project_value").val().toString().split(","));
        cons.push(project);
    } else {
        if ($('#reporttype').val() == "发现bug数量") {
            project.push("AND");
            project.push("project_id");
            project.push(" = ");
            project.push([pId]);
            cons.push(project);
        }
    }

    if ($("#probability").val() != null && $("#probability").val().toString() != "") {
        probability.push("AND");
        probability.push("cf_2");
        probability.push(" = ");
        probability.push($("#probability").val().toString().split(","));
        cons.push(probability);
    }

    if ($("#priority_id").val() != null && $("#priority_id").val().toString() != "") {
        priority_id.push("AND");
        priority_id.push("priority_id");
        priority_id.push(" = ");
        priority_id.push($("#priority_id").val().toString().split(","));
        cons.push(priority_id);
    }

    if (assgId.length > 0)
        if ($('#reporttype').val() != "发现bug数量")
            cons.push(["AND", "assigned_to_id", " = ", [assgId]]);

    var nObj = {};
    if ($('#reporttype').val() == "发现bug数量") {
        var andObj = {};
        andObj[" AND 0"] = {};
        $.each(cons, function (index, item) {
            andObj[" AND 0"][index] = [item[1], item[2], item[3]];
        });
        nObj[" AND 0"] = andObj[" AND 0"];

        var orObj = {};
        orObj[" OR 1"] = {};
        orObj[" OR 1"][0] = ["cf_8", " = ", [uId.toString()]];
        orObj[" OR 1"][1] = ["author_id", " = ", [uId.toString()]];
        nObj[" OR 1"] = orObj[" OR 1"];

        var robj = {};
        robj[" AND 0"] = nObj;
        nObj = robj;
    } else {
        nObj[" AND 0"] = {};
        $.each(cons, function (index, item) {
            nObj[" AND 0"][index] = [item[1], item[2], item[3]];
        });
    }

    $.post("/conditions"
        , {
            condition: {
                folder_id: '',
                category: 1,
                name: report_name,
                is_folder: false,
                json: JSON.stringify(nObj[" AND 0"] != {} ? nObj : {})
            }
        }
        , function (result) {
            var form = $('#redirecttoissue');
            $('#condition_id').val(result);
            form.submit();
        })
        .fail(function () {
            timeoutMsgBox(1500, "查询失败！请确认你是否有权限！");
        })
}

function productionTpeChart(chartId, title, legendData, seriesData) {
    var myChart = echarts.init(document.getElementById(chartId), 'infographic');
    // myChart.showLoading();

    var option = {
        title: {
            shadowColor: 'rgba(0, 0, 0, 0.5)',
            shadowBlur: 10,
            text: title,
            x: "left"
        },
        tooltip: {
            padding: 5,
            backgroundColor: '#222',
            borderColor: '#777',
            borderWidth: 1,
            trigger: 'item',
            formatter: "{a} <br/>{b} : {c} ({d}%)"
        },
        legend: {
            show: true,
            padding: 30,
            data: legendData
        },
        grid: {
            left: '30',
            right: '20',
            bottom: '30',
            containLabel: true
        },
        series: [{
            name: '产品中心数据汇总',
            type: 'pie',
            radius: '55%',
            center: ['50%', '60%'],
            data: seriesData,
            itemStyle: {
                emphasis: {
                    shadowBlur: 10,
                    shadowOffsetX: 0,
                    shadowColor: 'rgba(0, 0, 0, 0.5)'
                }
            }
        }]
    };

    myChart.setOption(option);
}

function onShowCalculation(reporttype) {
    var reporttype = $('#' + reporttype.toString()).val();
    var showContent = "";

    switch (reporttype.toString()) {
        case "bug数量":
            showContent = "<li><strong>指派给某某的BUG总数</strong></li>";
            break;
        case "有效数量":
            showContent = "<li><strong>BUG状态为（三方分析+提交+分配+重分配+打开+重打开+已修复+已验证+关闭）</strong></li>";
            break;
        case "发现bug数量":
            showContent = "<li>筛选字段“发现者”，按名字计数 </li></br>";
            showContent += "<li>如果“发现者”为空，则筛选“提交者”，按名字计数 </li></br>";
            showContent += "<li><strong>发现BUG数=符合条件（1）的数量 与符合条件（2）的数量之和</strong></li>";
            break;
        case "重打开数量":
            showContent = "<li><strong>重打开BUG数=每个BUG的所有状态（历史状态和当前状态）中计算状态为“重打开”的次数</strong></li>";
            break;
        case "遗留数量":
            showContent = "<li><strong>筛选当前状态为未解（分配、打开、重打开、重分配、三方分析）的BUG并计数</strong></li>";
            break;
        case "已解决数量":
            showContent = "<li><strong>已解决BUG数=筛选当前状态为已解（已修复、已验证、关闭）的BUG状态并计数</strong></li>";
            break;
        case "已解的重分配数量":
            showContent = "<li>已解BUG=筛选当前状态为已解（已修复、已验证、关闭）状态 </li></br>";
            showContent += "<li><strong>每个BUG重分配次数=符合条件（1）的BUG中，计算BUG历史状态为“重分配”的次数相加</strong></li>";
            break;
        case "冗余数量":
            showContent = "<li>冗余BUG数=BUG总数-BUG状态为（三方分析+提交+分配+重分配+打开+重打开+已修复+已验证+关闭） </li>";
            break;
        case "平均已解的重分配数量":
            showContent = "<li>已解BUG=筛选当前状态为已解（已修复、已验证、关闭）状态</li></br>";
            showContent += "<li>每个BUG重分配次数=符合条件（1）的BUG中，计算BUG历史状态为“重分配”的次数相加</li></br>";
            showContent = "<li><strong>平均已解BUG重分配次数=每个BUG重分配次数/已解BUG数</strong></li>";
            break;
        case "已分析BUG数":
            showContent = "<li><strong>已分析BUG数=筛选BUG状态为打开、重分配，并计数</strong></li>";
            break;
        case "平均遗留时长":
            showContent = "<li>遗留BUG数=筛选BUG的状态为提交、分配、打开、重分配、重打开,并计数</li></br>";
            showContent += "<li>遗留时长=符合条件（1）的BUG状态为“提交”到目前的时间差</li></br>";
            showContent += "<li><strong>平均遗留时长=所有BUG遗留时长之和/遗留BUG总数</strong></li>";
            break;
        case "平均未分配时长":
            showContent = "<li>未分配BUG数=筛选BUG当前状态为“提交”并计数</li></br>";
            showContent += "<li>未分配时长=BUG状态为“提交”的更新时间到目前的时间差</li></br>";
            showContent += "<li><strong>平均未分配时长=所有BUG未分配时长之和/未分配BUG数</strong></li>";
            break;
        case "平均未解决时长":
            showContent = "<li>未解决BUG数=筛选BUG的当前状态为分配、打开、重分配、重打开、三方分析,并计数</li></br>";
            showContent += "<li>未解决的时长=BUG历史状态为“分配”到目前的时间差</li></br>";
            showContent += "<li><strong>平均未解决时长=所有BUG未解决时长之和/未解决BUG数</strong></li>";
            break;
        case "平均未处理时长":
            showContent = "<li>未处理BUG数=筛选BUG的当前状态为分配、打开、重分配、重打开、三方分析,并计数</li></br>";
            showContent += "<li>未处理的时长=符合条件（1）的BUG的当前状态当前责任人最后一次更新时间到目前时间之差</li></br>";
            showContent += "<li><strong>平均未处理时长=所有BUG未处理时长之和/未处理BUG数</strong></li>";
            break;
        case "平均未走读时长":
            showContent = "<li>未走读BUG数=筛选BUG状态为“已修复”的BUG，并计数</li></br>";
            showContent += "<li>未走读时长=BUG状态为“已修复”的更新时间到目前时间差</li></br>";
            showContent += "<li><strong>平均未走读时长=所有BUG未走读时长之和/未走读BUG数</strong></li>";
            break;
        case "平均未验证时长":
            showContent = "<li>未验证BUG数=筛选BUG当前状态为“已验证或已修复”，并计数（备注：如果一个BUG同时有已验证和已修复的状态，则选已验证）</li></br>";
            showContent += "<li>未验证时长=BUG状态最后一次为“已验证或已修复”的更新时间到目前时间差</li></br>";
            showContent += "<li><strong>平均未验证时长=所有BUG未验证时长之和/未验证BUG数</strong></li>";
            break;
        case "平均关闭时长":
            showContent = "<li>关闭BUG数=筛选BUG当前状态为“关闭”的BUG并计数</li></br>";
            showContent += "<li>关闭时长=BUG最后一次“关闭”的更新时间-BUG“创建于”的时间差</li></br>";
            showContent += "<li><strong>平均关闭时长=所有BUG关闭时长之和/关闭BUG数</strong></li>";
            break;
        case "平均分配时长":
            showContent = "<li>已分配BUG数=筛选BUG历史状态和当前状态有“分配”的BUG并计数</li></br>";
            showContent += "<li>分配时长=BUG状态第一次为“分配”的更新时间-BUG“创建于”的时差</li></br>";
            showContent += "<li><strong>平均分配时长=所有BUG分配时长之和/已分配BUG数</strong></li>";
            break;
        case "平均解决时长":
            showContent = "<li>已解决BUG数=筛选当前状态为已解（已修复、已验证、关闭）的BUG状态并计数</li></br>";
            showContent += "<li>解决时长=BUG最后一次“已修复”的更新时间-BUG历史状态第一次“分配”的更新时间差</li></br>";
            showContent += "<li><strong>平均解决时长=所有BUG解决时长之和/已解决BUG数</strong></li>";
            break;
        case "平均验证时长":
            showContent = "<li>已验证BUG数=筛选BUG历史状态有“关闭”的BUG并计数</li></br>";
            showContent += "<li>验证时长=BUG状态为“关闭”的更新时间-BUG历史状态为“已验证、已修复”的更新时间差</li></br>";
            showContent += "<li><strong>平均验证时长=所有BUG验证时长之和/已验证BUG数</strong></li>";
            break;
        case "平均走读时长":
            showContent = "<li>已走读BUG数=筛选BUG历史状态有“已验证”的BUG并计数</li></br>";
            showContent += "<li>走读时长=BUG状态为“已验证”的更新时间-BUG历史状态为“已修复”的更新时间差</li></br>";
            showContent += "<li><strong>平均走读时长=所有BUG走读时长之和/已走读BUG数</strong></li>";
            break;
        case "解决率":
            showContent = "<li><strong>状态为（已修复+已验证+关闭）bug数/状态为（三方分析+已修复+已验证+关闭+分配+打开+重分配+重打开）的BUG数</strong></li>";
            break;
        case "重打开率":
            showContent = "<li>已解决BUG数=筛选状态为已解（已修复、已验证、关闭）的BUG状态并计数</li></br>";
            showContent += "<li><strong>重打开率=重打开BUG数/已解决BUG数</strong></li>";
            break;
        case "重分配率":
            showContent = "<li>已解BUG数=筛选BUG当前状态为：已修复、已验证、关闭，并计数</li></br>";
            showContent += "<li>已解BUG的重分配次数：满足条件（1）的BUG中，历史状态有“重分配”并计数</li></br>";
            showContent += "<li>已解BUG的重分配率=已解BUG的重分配次数/已解BUG数</li>";
            break;
        case "分配准确率":
            showContent = "<li>已解BUG数=筛选BUG状态为：已修复、已验证、关闭，并计数</li></br>";
            showContent += "<li>分配正确数=符合条件（1）中的BUG，状态为“分配”时的Owner和将状态变为“已修复”时 的Owner是同一个人，并计数</li></br>";
            showContent += "<li><strong>分配准确率=分配正确数/已解BUG数</strong></li>";
            break;
        default:
            break;
    }
    showContent += "<li>所有报表的计算方法都有的筛选条件：作者类型=测试人员</li>";
    var box = msgBox('<ol style="padding-bottom: 5px;color: darkorange;">' + showContent + '</ol>');

    setTimeout(function () {
        layer.close(box);
    }, 100000);
}

var isCommited = false;
function checkSubmit() {
    if (!isCommited) {
        isCommited = true;
        return true;
    } else {
        timeoutMsgBox(1500, "请不要重复提交！");
        return false;
    }
}

function changeControlStatus() {
    if ($("#reporttype").val().toString().indexOf("时长") > -1
        || $("#reporttype").val().toString().indexOf("率") > -1
        || ["bug数量", "发现bug数量", "重打开数量"].indexOf($("#reporttype").val().toString()) == -1) {
        disabledControl("dwm_yn");
        disabledControl("start_dt");

        $("#dwm_yn").attr("checked", false);
    } else {
        enabledControl("dwm_yn");
        enabledControl("start_dt");
    }
}

function getReportCondition() {
    var hrefUrl = formToString($('#filterform').get(0));

    var report_conditions = new Object();
    report_conditions.auto = checkboxStatus('auto') ? 1 : 0;
    report_conditions.groupby = $('#groupby').val();
    report_conditions.charttype = $('#charttype').val();
    report_conditions.dwm_yn = checkboxStatus('dwm_yn') ? 1 : 0;
    // report_conditions.dwm_yn = getQueryStringFromUrl(hrefUrl,"dwm_yn").toString() == "1" ? 1 : 0;
    report_conditions.dwm = $('#day_week_month').val();
    report_conditions.start_dt = $('#start_dt').val();
    report_conditions.end_dt = $('#end_dt').val();
    return report_conditions;
}

function getReportConditionWin() {
    var report_conditions = new Object();
    report_conditions.auto = checkboxStatus('auto_window') ? 1 : 0;
    report_conditions.groupby = $('#groupby_window').val();
    report_conditions.charttype = $('#charttype_window').val();
    report_conditions.dwm_yn = checkboxStatus('dwm_yn_window') ? 1 : 0;
    report_conditions.dwm = $('#day_week_month_window').val();
    report_conditions.start_dt = $('#start_dt_window').val();
    report_conditions.end_dt = $('#end_dt_window').val();
    return report_conditions;
}

function getRadiosSelectedItem() {
    var selected = ""
    $('.btn-group-report').find('label').each(function () {
        if ($(this).hasClass("active"))
            selected = $(this).text();
    });

    return selected;
}

function checkboxStatus(cbId) {
    if ($('#' + cbId).is(':checked'))
        return true
    else
        return false
}

function getQueryConditions() {
    var conditions = [], role = [], project = [], probability = [], priority_id = [];
    if ($("#role_value").val() != null && $("#role_value").val().toString() != "") {
        role.push($("#role").val().toString());
        role.push("=");
        role.push($("#role_value").val().toString().split(","));
        conditions.push(role);
    }

    if ($("#project_value").val() != null && $("#project_value").val().toString() != "") {
        project.push($("#project").val().toString());
        project.push("=");
        project.push($("#project_value").val().toString().split(","));
        conditions.push(project);
    }

    if ($("#probability").val() != null && $("#probability").val().toString() != "") {
        probability.push("cf2");
        probability.push("=");
        probability.push($("#probability").val().toString().split(","));
        conditions.push(probability);
    }

    if ($("#priority_id").val() != null && $("#priority_id").val().toString() != "") {
        priority_id.push("priority_id");
        priority_id.push("=");
        priority_id.push($("#priority_id").val().toString().split(","));
        conditions.push(priority_id);
    }

    var obj = {};
    obj[" AND 0"] = {};
    $.each(conditions, function (index, item) {
        obj[" AND 0"][index] = item;
    });

    return obj;
}

var axisLabelFormat = function (obj) {
    var stringFormat = "";
    if ($('#reporttype').val().indexOf("数量") > -1) {
        stringFormat = obj;
    } else if ($('#reporttype').val().indexOf("时长") > -1) {
        if (parseInt(obj) > 3600 * 24) {
            stringFormat = parseInt(parseInt(obj) / 3600 / 24 + 1).toString() + "天";
        } else if (parseInt(obj) < 3600 * 24 && parseInt(obj) > 3600) {
            stringFormat = parseInt(parseInt(obj) / 3600 + 1).toString() + "时";
        } else if (parseInt(obj) < 3600) {
            stringFormat = parseInt(parseInt(obj) / 60 + 1).toString() + "分";
        }
    } else if ($('#reporttype').val().indexOf("率") > -1) {
        stringFormat = obj + '%';
    }

    return stringFormat;
}

var toolTipFormat = function (obj) {
    var stringFormat = "";
    if ($('#reporttype').val().indexOf("数量") > -1) {
        stringFormat = obj.name + ':' + obj.value;
    } else if ($('#reporttype').val().indexOf("时长") > -1) {
        stringFormat = obj.name + ':' + secondsFormatter(obj.value);
    } else if ($('#reporttype').val().indexOf("率") > -1) {
        stringFormat = obj.name + ':' + roundNum(obj.value, 2) + '%';
    }

    return stringFormat;
}

function currentDate(time) {
    var current = new Date();
    var localdate = current.toLocaleDateString().replace('/', '-').replace('/', '-');
    var localtime = current.getHours() + ":" + current.getMinutes() + ":" + current.getSeconds();

    return Date.parse(time ? localdate + " " + localtime : localdate);
}

function roundNum(num, v) {
    var vv = Math.pow(10, v);
    return Math.round(num * vv) / vv;
}

function secondsFormatter(seconds) {
    var stringFormat = seconds.toString() + "时";
    // if (seconds < 60) {
    //     stringFormat = parseInt(seconds).toString() + "秒";
    // } else if (seconds >= 60 && seconds < 3600) {
    //     stringFormat = parseInt(seconds / 60).toString() + "分" + parseInt(seconds % 60).toString() + "秒";
    // } else if (seconds >= 3600 && seconds < 3600 * 24) {
    //     stringFormat = parseInt(seconds / 3600).toString() + "时" + parseInt(seconds % 3600 / 60).toString() + "分" + parseInt(seconds % 60).toString() + "秒";
    // } else if (seconds >= 3600 * 24) {
    //     stringFormat = parseInt(seconds / 3600 / 24).toString() + "天" + parseInt(seconds % (3600 * 24) / 3600).toString() + "时" + parseInt(seconds % 3600 / 60).toString() + "分" + parseInt(seconds % 60).toString() + "秒";
    // }

    return stringFormat;
}

function formValidator() {
    $('.form-horizontal').validate({
        errorElement: 'span',
        errorClass: 'help-block',
        focusInvalid: false,
        rules: {
            reportname: {
                required: true
            },
            password: {
                required: true
            },
            intro: {
                required: true
            }
        },
        messages: {
            name: {
                required: "Username is required."
            },
            password: {
                required: "Password is required."
            },
            intro: {
                required: "Intro is required."
            }
        },

        highlight: function (element) {
            $(element).closest('.form-group').addClass('has-error');
        },

        success: function (label) {
            label.closest('.form-group').removeClass('has-error');
            label.remove();
        },

        errorPlacement: function (error, element) {
            element.parent('div').append(error);
        },

        submitHandler: function (form) {
            form.submit();
        }
    });

    $('.form-horizontal input').keypress(function (e) {
        if (e.which == 13) {
            if ($('.form-horizontal').validate().form()) {
                $('.form-horizontal').submit();
            }
            return false;
        }
    });
}

function initEasyTree(treeId, options) {
    $('#' + treeId.toString()).easytree(options);
}

function returnEasyTree(id) {
    var closest_id = $(id).closest(".panel").find(".panel-collapse")[0].id
    if (closest_id == "filterStar")
        return false
    else if (closest_id == "filterClock")
        return true
    else if (closest_id == "filterCog")
        return true
}

function toggleNodes(nodes, openOrClose) {
    var i = 0;
    for (i = 0; i < nodes.length; i++) {
        nodes[i].isExpanded = openOrClose == "open"; // either expand node or don't

        // if has children open/close those as well
        if (nodes[i].children && nodes[i].children.length > 0) {
            toggleNodes(nodes[i].children, openOrClose);
        }
    }
}

function concatElementByObject(obj) {
    var stringUrl = "";
    $.each(obj, function (idx, item) {
        stringUrl += item.key;
    })
}


/* Personalize Report Begin */
function queryBugMovingTime(menuid) {
    remote("/reports/personalize?menuid=" + menuid + "&" + formToString($('#formBugMovingTime').get(0)), "POST", {}, function (res) {
        if (res != null || res != undefined) {
            var columns = ["问题ID", "项目", "所有状态", "状态更新时间", "状态操作者",
                "作者", "指派者", "指派者部门", "历史指派给", "概率", "解决版本", "验证版本",
                "通过E-consulter分析", "研发分析结论", "类型", "模块", "备注"];
            var table = "<table class='list issues sort-by-id sort-desc  table table-striped table-bordered'><thead>";

            var thead_ths = "<tr>";
            $.grep(columns, function (row) {
                thead_ths += "<th>" + row + "</th>";
            });
            table += thead_ths + "</tr></thead><tbody>";
            $.each(res.rows, function (idx, item) {
                var tbody_ths = "";
                $.grep(columns, function (col) {
                    if (col == "问题ID") {
                        tbody_ths += "<th><a href='/issues/" + item[col].toString() + "'" + " target='_blank'" + "</a>" + item[col].toString() + "</th>";
                    } else {
                        tbody_ths += "<th>" + item[col].toString() + "</th>";
                    }
                });
                table += "<tr>" + tbody_ths + "</tr>";
            });
            table += "</tbody></table>";
            $('.autoscroll').empty().append(table);
        }
    });
}

function queryLeaveTimesAndRate() {
    try {
        var objQuery = new Object();
        objQuery.project_id = $('#project').val();
        objQuery.dwm = $('#dwm').val();
        objQuery.start_dt = $('#start_dt').val();
        objQuery.end_dt = $('#end_dt').val();

        remote("/reports/personalize?menuid=" + getQueryString("menuid") + "&" + formToString($('#queryForm').get(0)), "POST", {}, function (res) {
            if (res != null || res != undefined) {
                var xAxisData = res.days;
                var amountData = [];
                var rateData = [];

                $.each(xAxisData, function (inx, day) {
                    var amountSum = 0;
                    var amountDateSum = 0;

                    $.each(res.rows, function (idx, item) {
                        amountSum += parseInt(item["d_" + day]);
                        amountDateSum += parseInt(item["amount"]);
                    });

                    amountData.push(amountSum);
                    rateData.push(roundNum(amountSum * 1000 / amountDateSum, 4));
                });

                var myChart = echarts.init(document.getElementById("gioneeChart"), 'infographic');
                var colors = ['#F4A460', '#FF3030'];
                var option = {
                    color: colors,
                    title: {
                        text: "遗留超时数量及遗留率"
                    },
                    tooltip: {
                        trigger: 'axis',
                        axisPointer: {
                            animation: false
                        }
                    },
                    legend: {
                        show: true,
                        data: ["遗留超时数量", "遗留率"]
                    },
                    grid: {
                        left: 30,
                        right: 50,
                        bottom: 60
                    },
                    toolbox: {
                        show: true,
                        feature: {
                            dataZoom: {
                                yAxisIndex: 'none'
                            },
                            dataView: {readOnly: false},
                            restore: {},
                            saveAsImage: {show: true}
                        }
                    },
                    xAxis: {
                        type: 'category',
                        boundaryGap: false,
                        axisLine: {onZero: false},
                        data: xAxisData
                    },
                    yAxis: [
                        {
                            name: '遗留超时数量',
                            type: 'value'
                        },
                        {
                            name: '遗留率',
                            axisLabel: {
                                formatter: '{value} %'
                            },
                            type: 'value',
                            max: 100,
                            min: 0
                        }
                    ],
                    dataZoom: [
                        {
                            show: true,
                            realtime: true,
                            start: 0,
                            end: 100,
                            top: 25
                        }
                    ],
                    series: [
                        {
                            name: '遗留超时数量',
                            type: 'line',
                            data: amountData
                        },
                        {
                            name: '遗留率',
                            yAxisIndex: 1,
                            type: 'line',
                            data: rateData
                        }
                    ]
                };

                myChart.setOption(option);
            }
        });
    } catch (e) {
        console.log(e)
    }
}

function queryBugAnalysisTimeout(menuid) {
    remote("/reports/personalize?menuid=" + menuid + "&" + formToString($('#formBugAnalysisTimeout').get(0)), "POST", {}, function (res) {
        if (res.rows != undefined && res.rows != null) {
            var table = "<table class='table table-striped table-bordered table-hover'><thead><tr><th>月份</th>" +
                "<th>部门</th><th>姓名</th><th>分析超时数</th></tr></thead>";
            var trs = "";
            $.grep(res.rows, function (row) {
                trs += "<tr>";
                trs += "<th>" + row.month + "</th>";
                trs += "<th>" + row.deptname + "</th>";
                trs += "<th>" + row.username + "</th>";
                trs += "<th><a target='_blank' href='/issues?search=issues.id in (" + row.ids + ")'>" + row.amount + "</a></th>";
                trs += "</tr>";
            });
            table += "<tbody>" + trs + "</tbody></table>";
            $('#contentAnalysisTimeoutBug').empty().append(table);
        }
    })
}

function queryLeaveAmountAndSolvedRateRemote(remoteUrl) {
    remote(remoteUrl, "POST", {}, function (res) {
        if (res.rows != undefined && res.rows != null) {
            var table = "<table class='table table-striped table-bordered table-hover'><thead><tr><th>严重度&概率</th>" +
                "<th>未解决数</th><th>已解决数</th><th>合计</th><th>昨日解决率</th><th>今日解决率</th><th>标准</th>" +
                "<th>达标应解数</th><th>标准差值</th></tr></thead>";
            var trs = "";
            $.grep(res.rows, function (row) {
                trs += "<tr>"
                var ths = "";
                $.grep(row, function (item) {
                    ths += "<th>" + item + "</th>";
                });
                trs += ths + "</tr>";
            });
            table += "<tbody>" + trs + "</tbody></table>";
            $('.autoscroll').empty().append(table);
        }
    })
}

function queryLeaveAmountAndSolvedRate(menuid) {
    if (SMValidator.validate('#formLeaveAmountAndSolvedRate')) {
        var remoteUrl = "/reports/personalize?menuid=" + menuid + "&" + formToString($('#formLeaveAmountAndSolvedRate').get(0));
        queryLeaveAmountAndSolvedRateRemote(remoteUrl);
    }
}

function queryLeaveAmountRankByDeptRemote(remoteUrl) {
    remote(remoteUrl, "POST", {}, function (res) {
        if (res.rows != undefined && res.rows != null) {
            var myChart = echarts.init(document.getElementById("chartLeaveAmountRankByDept"), "walden");
            var amountData = [];
            var rateData = [];
            var xAxisData = [];
            $.grep(res.rows, function (row) {
                xAxisData.push(row[0].toString());
                amountData.push(row[1].toString());
                rateData.push(parseFloat(row[2].toString().replace('%', '')));
            });

            var option = {
                title: {
                    text: "TOP10遗留BUG数量部门分布"
                },
                tooltip: {
                    trigger: 'axis',
                    axisPointer: {
                        animation: false
                    }
                },
                legend: {
                    show: true,
                    data: ["遗留BUG数量", "解决率"]
                },
                toolbox: {
                    show: true,
                    feature: {
                        dataZoom: {
                            yAxisIndex: 'none'
                        },
                        dataView: {readOnly: false},
                        restore: {},
                        saveAsImage: {show: true}
                    }
                },
                xAxis: {
                    nameTextStyle: {
                        fontStyle: 'italic'
                    },
                    data: xAxisData,
                    axisLabel: {
                        interval: 0,
                        show: true
                    }
                },
                yAxis: [
                    {
                        name: '遗留BUG数量',
                        type: 'value',
                        nameTextStyle: {
                            fontStyle: 'italic'
                        }
                    },
                    {
                        name: '解决率',
                        axisLabel: {
                            formatter: '{value} %'
                        },
                        nameTextStyle: {
                            fontStyle: 'italic'
                        },
                        max: 100,
                        min: 0
                    }
                ],
                dataZoom: [
                    {
                        show: true,
                        realtime: true,
                        start: 0,
                        end: 100,
                        top: 25
                    }
                ],
                series: [
                    {
                        name: '遗留BUG数量',
                        label: {
                            normal: {
                                show: true,
                                position: 'top'
                            }
                        },
                        type: 'bar',
                        data: amountData
                    },
                    {
                        name: '解决率',
                        label: {
                            normal: {
                                show: true,
                                position: 'top'
                            }
                        },
                        type: 'line',
                        data: rateData
                    }
                ]
            };

            myChart.setOption(option);
        }
    })
}

function queryLeaveAmountRankByDept(menuid) {
    var remoteUrl = "/reports/personalize?menuid=" + menuid + "&" + formToString($('#formLeaveAmountRankByDept').get(0));
    queryLeaveAmountRankByDeptRemote(remoteUrl);
}

function queryLeaveAmountRankByMokuaiRemote(remoteUrl) {
    remote(remoteUrl, "POST", {}, function (res) {
        if (res.rows != undefined && res.rows != null) {
            var myChart = echarts.init(document.getElementById("chartLeaveAmountRankByMokuai"), 'infographic');
            var amountData = [];
            var xAxisData = [];
            $.grep(res.rows, function (row) {
                xAxisData.push(row.model.toString());
                amountData.push(parseInt(row.amount));
            });

            var option = {
                title: {
                    text: "TOP10遗留BUG数量模块分布"
                },
                grid: {
                    left: 30,
                    right: 20,
                    top: 50
                },
                tooltip: {
                    trigger: 'axis',
                    axisPointer: {
                        animation: false
                    }
                },
                legend: {
                    show: true,
                    data: ["遗留BUG数量"]
                },
                toolbox: {
                    show: true,
                    feature: {
                        dataZoom: {
                            yAxisIndex: 'none'
                        },
                        dataView: {readOnly: false},
                        restore: {},
                        saveAsImage: {show: true}
                    }
                },
                xAxis: {
                    data: xAxisData,
                    axisLabel: {
                        interval: 0,
                        show: true
                    }
                },
                yAxis: [
                    {
                        name: '遗留BUG数量',
                        type: 'value'
                    }
                ],
                dataZoom: [
                    {
                        show: true,
                        realtime: true,
                        start: 0,
                        end: 100,
                        top: 25
                    }
                ],
                series: [
                    {
                        name: '遗留BUG数量',
                        label: {
                            normal: {
                                show: true,
                                position: 'top'
                            }
                        },
                        type: 'bar',
                        data: amountData
                    }
                ]
            };

            myChart.setOption(option);
        }
    });
}

function queryLeaveAmountRankByMokuai(menuid) {
    var remoteUrl = "/reports/personalize?menuid=" + menuid + "&" + formToString($('#formLeaveAmountRankByMokuai').get(0));
    queryLeaveAmountRankByMokuaiRemote(remoteUrl);
}

function queryLeaveAmountRankByIssueCategoryRemote(remoteUrl) {
    remote(remoteUrl, "POST", {}, function (res) {
        if (res.rows != undefined && res.rows != null) {
            var myChart = echarts.init(document.getElementById("chartLeaveAmountRankByIssueCategory"), 'infographic');
            var amountData = [];
            var xAxisData = [];
            $.grep(res.rows, function (row) {
                xAxisData.push(row.issue_category.toString());
                amountData.push(parseInt(row.amount));
            });

            var option = {
                title: {
                    text: "TOP10遗留BUG数量问题分类分布"
                },
                grid: {
                    left: 30,
                    right: 20,
                    top: 50
                },
                tooltip: {
                    trigger: 'axis',
                    axisPointer: {
                        animation: false
                    }
                },
                legend: {
                    show: true,
                    data: ["遗留BUG数量"]
                },
                toolbox: {
                    show: true,
                    feature: {
                        dataZoom: {
                            yAxisIndex: 'none'
                        },
                        dataView: {readOnly: false},
                        restore: {},
                        saveAsImage: {show: true}
                    }
                },
                xAxis: {
                    data: xAxisData,
                    axisLabel: {
                        interval: 0,
                        show: true
                    }
                },
                yAxis: [
                    {
                        name: '遗留BUG数量',
                        type: 'value'
                    }
                ],
                dataZoom: [
                    {
                        show: true,
                        realtime: true,
                        start: 0,
                        end: 100,
                        top: 25
                    }
                ],
                series: [
                    {
                        name: '遗留BUG数量',
                        label: {
                            normal: {
                                show: true,
                                position: 'top'
                            }
                        },
                        type: 'bar',
                        data: amountData
                    }
                ]
            };

            myChart.setOption(option);
        }
    });
}

function queryLeaveAmountRankByIssueCategory(menuid) {
    var remoteUrl = "/reports/personalize?menuid=" + menuid + "&" + formToString($('#formLeaveAmountRankByIssueCategory').get(0));
    queryLeaveAmountRankByIssueCategoryRemote(remoteUrl);
}

function queryTimeoutAndUnhandleBugCoverageRemote(remoteUrl) {
    remote(remoteUrl, "POST", {}, function (res) {
        if (res.rows != undefined && res.rows != null) {
            var myChart = echarts.init(document.getElementById("chartTimeoutAndUnhandleBugCoverage"), 'infographic');
            var xAxisData = res.days;
            var colors = ['#F4A460', '#FF3030'];

            var option = {
                color: colors,
                title: {
                    text: "超时未处理BUG分布"
                },
                tooltip: {
                    trigger: 'axis',
                    axisPointer: {
                        animation: true
                    }
                },
                grid: {
                    left: 30,
                    right: 35,
                    bottom: 150
                },
                toolbox: {
                    show: true,
                    feature: {
                        dataZoom: {
                            yAxisIndex: 'none'
                        },
                        dataView: {readOnly: false},
                        restore: {},
                        saveAsImage: {show: true}
                    }
                },
                yAxis: [
                    {
                        name: '数量',
                        type: 'value'
                    },
                    {
                        name: '率',
                        axisLabel: {
                            formatter: '{value}%'
                        },
                        type: 'value',
                        min: 1,
                        max: 100
                    }
                ],
                dataZoom: [
                    {
                        show: true,
                        realtime: true,
                        start: 30,
                        end: 60,
                        top: 5
                    }
                ]
            };

            option.legend = {};
            option.legend.show = true;
            option.legend.selectedMode = 'single';
            option.legend.bottom = 0;
            option.legend.data = [];

            option.xAxis = {};
            option.xAxis.type = 'category';
            option.xAxis.boundaryGap = false;
            option.xAxis.axisLine = {onZero: false};
            option.xAxis.data = xAxisData;
            option.xAxis.axisLabel = {
                interval: 0,
                show: true,
                rotate: -45
            };

            option.series = [];
            res.rows.forEach(function (project) {
                var amountData = [];
                var rateData = [];

                option.legend.data.push(project.projectname);
                $.each(xAxisData, function (inx, day) {
                    amountData.push(parseInt(project["d_" + day]));
                    rateData.push(parseFloat(project["l_" + day]) * 100);
                });
                option.series.push({name: project.projectname, type: 'line', data: amountData});
                option.series.push({name: project.projectname, type: 'line', data: rateData});
            });

            myChart.setOption(option);
        }
    });
}

function queryTimeoutAndUnhandleBugCoverage(menuid) {
    var remoteUrl = "/reports/personalize?menuid=" + menuid + "&" + formToString($('#formTimeoutAndUnhandleBugCoverage').get(0));
    queryTimeoutAndUnhandleBugCoverageRemote(remoteUrl);
}

function queryLeaveAmountGroupbyReasonAndOwner() {
    remote("/reports/personalize?menuid=" + getQueryString("menuid") + "&" + formToString($('#queryForm').get(0)), "POST", {}, function (res) {
        if (res.rows != undefined && res.rows != null) {
            console.log(res.rows);
        }
    })
}

function queryBugVerificatingTime(menuid) {
    remote("/reports/personalize?menuid=" + menuid + "&" + formToString($('#formBugVerificatingTime').get(0)), "POST", {}, function (res) {
        if (res.rows != undefined && res.rows != null) {
            var table = "<table class='table table-striped table-bordered table-hover'><thead><tr><th>#</th><th>验证时长(H)</th><th>作者</th><th>作者部门</th></tr></thead>";
            var trs = "";
            $.each(res.rows, function (index, row) {
                trs += "<tr>";
                trs += "<th><a href='/issues/" + row.iid.toString() + "'" + " target='_blank'" + "</a>" + row.iid.toString() + "</th>";
                trs += "<th>" + row.amount + "</th>";
                trs += "<th>" + row.username + "</th>";
                trs += "<th>" + row.deptname + "</th>";
                trs += "</tr>";
            });
            table += "<tbody>" + trs + "</tbody></table>";
            $('.autoscroll').empty().append(table);
        }
    })
}

function queryMovingAndBackToOwner(menuid) {
    remote("/reports/personalize?menuid=" + menuid + "&" + formToString($('#formMovingAndBackToOwner').get(0)), "POST", {}, function (res) {
        if (res.rows != undefined && res.rows != null) {
            var table = "<table class='table table-striped table-bordered table-hover'><thead><tr><th>#</th><th>标题</th><th>指派者</th><th>上次指派者</th><th>更新时间</th><th>注释说明</th></tr></thead>";
            var trs = "";
            $.each(res.rows, function (index, row) {
                trs += "<tr>";
                trs += "<th><a href='/issues/" + row.iid.toString() + "'" + " target='_blank'" + "</a>" + row.iid.toString() + "</th>";
                trs += "<th>" + row.subject.toString() + "</th>";
                trs += "<th>" + row.username.toString() + "</th>";
                trs += "<th>" + row.jusername.toString() + "</th>";
                trs += "<th>" + row.updated_dt.toString().replace("T", " ").replace(".000+08:00", "") + "</th>";
                trs += "<th>" + row.markpoint + "</th>";
                trs += "</tr>";
            });
            table += "<tbody>" + trs + "</tbody></table>";
            $('.autoscroll').empty().append(table);
        }
    })
}

function generateDoubleXaxilsChart(actualData, chartId, title) {
    var gioneeChart = echarts.init(document.getElementById(chartId), 'infographic');
    var metadata = {
        flag: true,
        quarter: [],
        month: [],
        data1: [],
        data2: [],
        data3: [],
        data4: [],
        x_major_offset: actualData[0][1].length,
        init: function () {
            if (metadata.flag) {
                for (var i = 0; i < actualData.length; i++) {
                    if (i === 0) {
                        metadata.quarter.push(actualData[i][0]);
                    } else {
                        // 与子分类列匹配
                        metadata.quarter.push(actualData[i - 1][0] === actualData[i][0] ? '' : actualData[i][0]);
                    }
                    metadata.month.push(actualData[i][1]);
                    metadata.data1.push(actualData[i][2]);
                    metadata.data2.push(actualData[i][3]);
                    metadata.data3.push(actualData[i][4]);
                    metadata.data4.push('');
                    // 计算子分类字符长度（按汉字计算，*12号字体）
                    metadata.x_major_offset = metadata.x_major_offset > actualData[i][1].length ? metadata.x_major_offset : actualData[i][1].length;
                }
                metadata.flag = false;
            }
            return metadata;
        }
    };

    var option = {
        title: {
            text: title
        },
        tooltip: {
            axisPointer: {
                type: 'shadow'
            },
            trigger: 'axis'
        },
        grid: {
            left: 30,
            right: 35,
            bottom: metadata.init().x_major_offset * 12 + 30
        },
        legend: {
            data: ['S3-一般', 'S2-严重', 'S1-致命']
        },
        calculable: true,
        xAxis: [
            {
                type: 'category',
                axisLabel: {
                    interval: 0,
                    show: true,
                    rotate: -45
                },
                axisLine: {show: false},
                axisTick: {show: false},
                splitArea: {show: false},
                data: metadata.init().month
            },
            {
                type: 'category',
                position: 'bottom',
                offset: metadata.init().x_major_offset * 12,
                axisLine: {show: false},
                axisTick: {
                    length: metadata.init().x_major_offset * 12 + 20,
                    lineStyle: {color: '#CCC'},
                    interval: function (index, value) {
                        return value !== '';
                    }
                },
                data: metadata.init().quarter
            }
        ],
        yAxis: [
            {
                type: 'value',
                name: '数量',
                interval: 50,
                axisLabel: {
                    formatter: '{value} 个'
                }
            }
        ],
        series: [
            {
                name: 'S3-一般',
                stack: '总量',
                type: 'bar',
                z: 1,
                barMaxWidth: 35,
                barGap: "10%",
                itemStyle: {
                    normal: {
                        color: "rgba(0,191,183,1)",
                        label: {
                            show: true,
                            textStyle: {
                                color: "#fff"
                            },
                            position: "insideTop",
                            formatter: function (p) {
                                return p.value > 0 ? (p.value) : '';
                            }
                        }
                    }
                },
                data: metadata.init().data1
            },
            {
                name: 'S2-严重',
                stack: '总量',
                type: 'bar',
                z: 1,
                barMaxWidth: 35,
                barGap: "10%",
                itemStyle: {
                    normal: {
                        color: "rgba(255,144,128,1)",
                        label: {
                            show: true,
                            textStyle: {
                                color: "#fff"
                            },
                            position: "insideTop",
                            formatter: function (p) {
                                return p.value > 0 ? (p.value) : '';
                            }
                        }
                    }
                },
                data: metadata.init().data2
            },
            {
                name: 'S1-致命',
                stack: '总量',
                type: 'bar',
                z: 1,
                barMaxWidth: 35,
                barGap: "10%",
                itemStyle: {
                    normal: {
                        color: "rgba(255,0,5,1)",
                        label: {
                            show: true,
                            textStyle: {
                                color: "#fff"
                            },
                            position: "insideTop",
                            formatter: function (p) {
                                return p.value > 0 ? (p.value) : '';
                            }
                        }
                    }
                },
                data: metadata.init().data3
            },
            {
                type: 'line',
                xAxisIndex: 1,
                z: 0,
                data: metadata.init().data4
            }
        ]
    };

    gioneeChart.setOption(option);
}

function queryLeaveAmountGroupByOwnerAndRomRemote(remoteUrl) {
    remote(remoteUrl, "POST", {}, function (res) {
        if (res.rows != undefined && res.rows != null) {
            generateDoubleXaxilsChart(res.rows, 'chartLeaveAmountGroupByOwnerAndRom', 'ROM未解BUG Owner分布');
        }
    });
}

function queryLeaveAmountGroupByOwnerAndRom(menuid) {
    var remoteUrl = "/reports/personalize?menuid=" + menuid + "&" + formToString($('#formLeaveAmountGroupByOwnerAndRom').get(0));
    queryLeaveAmountGroupByOwnerAndRomRemote(remoteUrl);
}

function queryLeaveAmountGroupByOwnerAndDriveRemote(remoteUrl) {
    remote(remoteUrl, "POST", {}, function (res) {
        if (res.rows != undefined && res.rows != null) {
            generateDoubleXaxilsChart(res.rows, 'chartLeaveAmountGroupByOwnerAndDrive', '驱动未解BUG Owner分布');
            // generateDoubleXaxilsChart(res.rows,'chartLeaveAmountGroupByOwnerAndSoftware','软件未解BUG Owner分布');
            // generateDoubleXaxilsChart(res.rows,'chartLeaveAmountGroupByOwnerAndFilm','影相未解BUG Owner分布');
        }
    });
}

function queryLeaveAmountGroupByOwnerAndDrive(menuid) {
    var remoteUrl = "/reports/personalize?menuid=" + menuid + "&" + formToString($('#formTimeoutAndUnhandleBugCoverage').get(0));
    queryLeaveAmountGroupByOwnerAndDriveRemote(remoteUrl);
}

function querySQA() {
    var pids = $('#project_sqa').val(), start_dt = $('#start_dt_sqa').val(), end_dt = $('#end_dt_sqa').val();
    var commonRemoteUrl = "project=project_id&project_value=" + pids.toString()
        + "&dwm_yn=1&created_time_yn=2&start_dt=" + start_dt + "&end_dt=" + end_dt;

    $.grep(["leave_amount_and_solved_rate", "leave_amount_rank_by_dept", "leave_amount_rank_by_mokuai",
        "leave_amount_rank_by_issue_category", "timeout_and_unhandle_bug_coverage", "leave_amount_group_by_owner_and_rom",
        "leave_amount_group_by_owner_and_drive"], function (mid) {
        switch (mid) {
            case "leave_amount_and_solved_rate":
                var remoteUrl = "/reports/personalize?menuid=" + mid + "&" + commonRemoteUrl
                    + ($('#rate_standard').val() == 0 ? "&s1b_rate=75&s1s_rate=55&s2b_rate=65&s2s_rate=45&s3b_rate=55&s3s_rate=35" : "&s1b_rate=100&s1s_rate=80&s2b_rate=100&s2s_rate=65&s3b_rate=80&s3s_rate=60");
                queryLeaveAmountAndSolvedRateRemote(remoteUrl);
                break;
            case "leave_amount_rank_by_dept":
                var remoteUrl = "/reports/personalize?menuid=" + mid + "&" + commonRemoteUrl;
                queryLeaveAmountRankByDeptRemote(remoteUrl);
                break;
            case "leave_amount_rank_by_mokuai":
                var remoteUrl = "/reports/personalize?menuid=" + mid + "&" + commonRemoteUrl;
                queryLeaveAmountRankByMokuaiRemote(remoteUrl);
                break;
            case "leave_amount_rank_by_issue_category":
                var remoteUrl = "/reports/personalize?menuid=" + mid + "&" + commonRemoteUrl;
                queryLeaveAmountRankByIssueCategoryRemote(remoteUrl);
                break;
            case "timeout_and_unhandle_bug_coverage":
                var remoteUrl = "/reports/personalize?menuid=" + mid + "&" + commonRemoteUrl + "&dwm=day&days=3";
                queryTimeoutAndUnhandleBugCoverageRemote(remoteUrl);
                break;
            case "leave_amount_group_by_owner_and_rom":
                var remoteUrl = "/reports/personalize?menuid=" + mid + "&" + commonRemoteUrl;
                queryLeaveAmountGroupByOwnerAndRomRemote(remoteUrl);
                break;
            case "leave_amount_group_by_owner_and_drive":
                var remoteUrl = "/reports/personalize?menuid=" + mid + "&" + commonRemoteUrl;
                queryLeaveAmountGroupByOwnerAndDriveRemote(remoteUrl);
                break;
        }
    });
}
/* Personalize Report End */


/* Add at 2017-1-11 By chenshuilong */
/* Spec Begin */
function onLockSpec(specId, projectId, is_new) {
    var spec_tr = $('[data-id="spec-' + specId.toString() + '"]');
    var postData = new Object();
    postData.spec_id = specId;
    postData.locked = spec_tr.children().eq(5).html().indexOf("fa fa-unlock") > -1;

    var remoteUrl = "/projects/" + projectId.toString() + "/specs/lock";
    if (is_new == "true") {
        layer.confirm("锁定前请检查所有应用的发布路径是否正确，确定要锁定吗？", {btn: ['取消', '确定']},
            function (cancal) {
                layer.close(cancal);
            },
            function () {
                remote(remoteUrl, "POST", postData, function (res) {
                    refreshPage();
                    layer.msg(res.message.toString());
                });
            }
        );
    } else {
        remote(remoteUrl, "POST", postData, function (res) {
            refreshPage();
            layer.msg(res.message.toString());
        });
    }
}

function onFreezeSpec(specId, projectId) {
    var spec_tr = $('[data-id="spec-' + specId.toString() + '"]');
    var postData = new Object();
    postData.spec_id = specId;
    postData.freezed = spec_tr.children().eq(6).html().indexOf("fa fa-unlock") > -1;

    var remoteUrl = "/projects/" + projectId.toString() + "/specs/freeze"
    remote(remoteUrl, "POST", postData, function (res) {
        refreshPage();
        layer.msg(res.message.toString());
    });
}

function onSetDefaultSpec(specId, projectId) {
    var postData = new Object();
    postData.spec_id = specId;
    postData.is_default = true;

    var remoteUrl = "/projects/" + projectId.toString() + "/specs/reset"
    remote(remoteUrl, "POST", postData, function (res) {
        refreshPage();
        layer.msg(res.message.toString());
    });
}

function onBatchHandleApp(url, remoteType, appid, projectid, specid, freezed, china_flag, currentSpecs) {
    var content = "<form id='frmHandle' style='width: 865px' class=\"form-horizontal\" action='" + url + "' accept-charset=\"UTF-8\" data-remote=\"true\" method=\"post\">"
        + "<div class=\"form-group\"><div class=\"col-xs-1\"></div><div class=\"col-xs-11\"><label for=\"ids\">父项目/子项目下的相同应用规格版本是否需要同步</label></div>"
        + "</div><div class=\"form-group\"><div class=\"col-xs-1\"></div><div class=\"col-xs-10\"><table class=\"csacsa table table-bordered table-hover table-striped\" id=\"freezeAppsTable\">"
        + "<thead><tr><th>序号</th><th>项目规格</th><th>规格版本</th><th>应用中文名</th><th>桌面显示名称</th><th>开发者信息</th><th>功能描述</th><th>是否需要同步</th></tr></thead><tbody>";
    remote('/projects/' + projectid.toString() + '/specs/get_parent_and_children_spec_version', "GET", {appid: appid, project_id: projectid, spec_id: specid, is_new: false}, function(result) {
        if (result.rows != undefined && result.rows != null) {
            var trs = "";
            $.grep(result.rows,function (row) {
                trs += "<tr>";
                trs += "<th>" + (result.rows.indexOf(row) + 1).toString() + "</th>";
                trs += "<th>" + (row.spec_name == null ? '-' : row.spec_name) + "</th>";
                trs += "<th>" + (row.app_version == null ? '-' : row.app_version) + "</th>";
                trs += "<th>" + (row.cn_name == null ? '-' : row.cn_name) + "</th>";
                trs += "<th>" + (row.desktop_name == null ? '-' : row.desktop_name) + "</th>";
                trs += "<th>" + (row.developer == null ? '-' : row.developer) + "</th>";
                trs += "<th>" + (row.mark == null ? '-' : row.mark) + "</th>";
                if (china_flag){
                    trs += "<th width='80px'><select name='sync[id_" + row.app_id + "]' class='form-control'><option value='1'>是</option><option value='0'>否</option></select></th>";
                } else {
                    if (currentSpecs.indexOf(row.spec_name.toString()) > -1){
                        trs += "<th width='80px'><select name='sync[id_" + row.app_id + "]' class='form-control'><option value='1'>是</option><option value='0'>否</option></select></th>";
                    } else {
                        trs += "<th width='80px'><select name='sync[id_" + row.app_id + "]' class='form-control'><option value='0'>否</option><option value='1'>是</option></select></th>";
                    }
                }
                trs += "</tr>";
            });
            content += trs;
            content += "</tbody></table></div><div class=\"col-xs-1\"></div></div></form>"

            freeze_window = layer.open({
                type: 1,
                title: '<b>提示</b>',
                area: ['880px', '680px'],
                zIndex: 666,
                moveType: 1,
                shadeClose: false,
                content: content,
                btn: ['取消', '确定'],
                yes: function(index, layero){
                    layer.close(freeze_window)
                },
                btn2: function(index, layero){
                    $('#frmHandle').submit();
                    layer.msg("操作成功");
                    refreshPage();
                }
            });
        }
    })
}

function onDelete(url, remoteType) {
    layer.confirm("数据一旦删除将无法恢复，确定要删除吗？", {btn: ['取消', '确定']},
        function (cancal) {
            layer.close(cancal);
        },
        function () {
            remote(url, remoteType, {}, function (res) {
                eval(res.message);
            });
        }
    );
}

function initDataTable(tId, opts) {
    opts.responsive = true;
    opts.autoFill = true;
    opts.lengthMenu = [[10, 25, 50, 100, -1], [10, 25, 50, 100, "全部"]];
    opts.language = {
        "sProcessing": "处理中...",
        "sLengthMenu": "显示 _MENU_ 项结果",
        "sZeroRecords": "没有匹配结果",
        "sInfo": "显示第 _START_ 至 _END_ 项结果，共 _TOTAL_ 项",
        "sInfoEmpty": "显示第 0 至 0 项结果，共 0 项",
        "sInfoFiltered": "(由 _MAX_ 项结果过滤)",
        "sInfoPostFix": "",
        "sSearch": "搜索:",
        "sUrl": "",
        "sEmptyTable": "表中数据为空",
        "sLoadingRecords": "载入中...",
        "sInfoThousands": ",",
        "oPaginate": {
            "sFirst": "首页",
            "sPrevious": "上页",
            "sNext": "下页",
            "sLast": "末页"
        },
        "oAria": {
            "sSortAscending": ": 以升序排列此列",
            "sSortDescending": ": 以降序排列此列"
        }
    };

    $('#' + tId.toString()).DataTable(opts);
}

function changeGroupRadiosSelected(value) {
    if (value.toString() == "1") {
        $('#release_type_one').attr("checked", "checked");
        $('#release_type_two').removeAttr("checked");
        $('#release_type_three').removeAttr("checked");
    } else if (value.toString() == "2") {
        $('#release_type_two').attr("checked", "checked");
        $('#release_type_one').removeAttr("checked");
        $('#release_type_three').removeAttr("checked");
    } else if (value.toString() == "3") {
        $('#release_type_three').attr("checked", "checked");
        $('#release_type_two').removeAttr("checked");
        $('#release_type_one').removeAttr("checked");
    }
}

function fillSpecs(currentid, pid, select2_id) {
    remote('/projects/' + currentid + '/specs/get_project_specs', "GET", {pid: pid}, function (result) {
        if (result.success.toString() == "1") {
            var select = $('#' + select2_id);
            var opts = '';
            $.grep(result.rows, function (row) {
                opts += "<option value='" + row[0] + "'>" + row[1] + "</option>";
            });

            select.siblings(".select2-container").remove();
            select.val('').trigger("change");
            select.empty().append(opts);
            select.select2();
        }
    })
}

function fillVersions(currentid, spec_id, select2_id) {
    remote('/projects/' + currentid + '/specs/get_spec_main_versions', "GET", {spec_id: spec_id}, function (result) {
        if (result.success.toString() == "1") {
            var select = $('#' + select2_id);
            var opts = '';
            $.grep(result.rows, function (row) {
                opts += "<option value='" + row[0] + "'>" + row[1] + "</option>";
            });

            select.siblings(".select2-container").remove();
            select.val('').trigger("change");
            select.empty().append(opts);
            select.select2();
        }
    })
}

function onGenerateVersion(params) {
    remote('/api/virtual_version?1=1' + params, "GET", {}, function (result) {
        layer.alert(result.message.toString());
        if (result.success.toString() == "1"){
            layer.confirm("创建虚拟版本成功，是否要继续创建？", {btn: ['取消', '确定']},
                function (cancal) {
                    refreshPage();
                },
                function(ok){
                    layer.close(ok);
                }
            );
        }
    })
}
/* Spec End */


/* Add at 2017-04-25 By chenshuilong */
/* Product Definition Begin */
function generateDefinitionModuleTable(tableId, project_id) {
    remote("/projects/" + project_id + "/definitions/definition_modules", "POST", {}, function (res) {
        if (res.rows != undefined && res.rows != null) {
            var trs = "";
            $.grep(res.rows,function (row) {
                trs += "<tr>";
                trs += "<th>" + (res.rows.indexOf(row) + 1).toString() + "</th>";
                trs += "<th><a href='#' class='definitions-module-name'>" + row.name + "</a></th>";
                trs += "<th>" + row.parent_id + "</th>";
                trs += "<th>" + replaceOtherString(replaceOtherString(row.created_at,".000+08:00"),"T") + "</th>";
                trs += "<th>" + replaceOtherString(replaceOtherString(row.updated_at,".000+08:00"),"T") + "</th>";
                if(row.display == 1){
                    trs += "<th><a href='javascript:hideDefinitionModule(" + row.id + ",\"" + tableId + "\")'>隐藏</a></th>";
                }else {
                    trs += "<th><a href='javascript:displayDefinitionModule(" + row.id + ",\"" + tableId + "\")'>显示</a></th>";
                }
                trs += "</tr>";
            });

            $('#' + tableId.toString()).find("tbody").empty().append(trs);
            $('.definitions-module-name').editable({
                url: "/definition_section/edit_definition_module",
                type: 'text',
                pk: 1,
                name: 'definitions-module-name',
                validate: function(value) {
                    if($.trim(value) == '') return '不能为空！';
                },
                title: '请输入值'
            });
        }
    })
}

function generateDefinitionFieldTable(tableId, project_id) {
    remote("/projects/" + project_id + "/definitions/definition_custom_fields", "POST", {}, function (res) {
        if (res.rows != undefined && res.rows != null) {
            var trs = "";
            $.grep(res.rows,function (row) {
                trs += "<tr>";
                trs += "<th style='text-align: center;'><input type='checkbox' name='fields' value='" + row.id.toString() + "' /></th>";
                trs += "<th>" + (res.rows.indexOf(row) + 1).toString() + "</th>";
                trs += "<th>" + row.name + "</th>";
                trs += "<th>" + row.field_format + "</th>";
                trs += "<th>" + row.possible_values + "</th>";
                trs += "<th><span class=\"sort-handle ui-sortable-handle\" data-reorder-url=\"/custom_fields/" + row.id.toString() + "\" data-reorder-param=\"custom_field\" title=\"排序\"></span></th>";
                trs += "</tr>";
            });

            $('#' + tableId.toString()).find("tbody").empty().append(trs).positionedItems();
        }
    })
}

function onEditField(f) {
    f.editable({
        url: "/definition_section/edit_definition_module?id=" + 2,
        type: 'text',
        pk: 1,
        name: 'definitions-module-name',
        validate: function(value) {
            if($.trim(value) == '') return '不能为空！';
        },
        title: '请输入值'
    });
}

function generateProductDefinitionTable(tableId, definition_id, project_id) {
    remote("/projects/" + project_id + "/definitions/definition_custom_values?definition_id=" + definition_id, "POST", {}, function (res) {
        if (res.rows != undefined && res.rows != null) {
            var trs = "";
            $.grep(res.rows,function (row) {
                trs += "<tr>";
                trs += "<th>" + (res.rows.indexOf(row) + 1).toString() + "</th>";
                trs += "<th>" + row.module_name + "</th>";
                trs += "<th>" + row.name + "</th>";
                trs += "<th>" + row.field_format + "</th>";
                trs += "<th>" + row.value + "</th>";
                trs += "<th>" + row.sort + "</th>";
                trs += "<th><a href='javascript:deleteCustomValue(" + row.id + "," + definition_id + ")'>删除</a></th>";
                trs += "</tr>";
            });

            $('#' + tableId.toString()).find("tbody").empty().append(trs);
        }
    })
}

function generateModuleFieldTable(tableId, project_id) {
    remote("/projects/" + project_id + "/definitions/definition_module_fields", "POST", {}, function (res) {
        if (res.rows != undefined && res.rows != null) {
            var trs = "";
            $.grep(res.rows,function (row) {
                trs += "<tr>";
                trs += "<th>" + (res.rows.indexOf(row) + 1).toString() + "</th>";
                trs += "<th>" + row.m_name + "</th>";
                trs += "<th>" + row.cf_name + "</th>";
                trs += "<th><a href='javascript:deleteModuleField(" + row.id + ")'>删除</a></th>";
                trs += "</tr>";
            });

            $('#' + tableId.toString()).find("tbody").empty().append(trs);
        }
    })
}

function generateCompareModelTable(tableId, project_id) {
    remote("/projects/" + project_id + "/definitions/definition_compare_model", "POST", {}, function (res) {
        if (res.rows != undefined && res.rows != null) {
            var trs = "";
            $.grep(res.rows,function (row) {
                trs += "<tr>";
                trs += "<th>" + (res.rows.indexOf(row) + 1).toString() + "</th>";
                trs += "<th>" + row.name + "</th>";
                trs += "<th>" + row.author + "</th>";
                trs += "<th>" + replaceOtherString(replaceOtherString(row.created_at,".000+08:00"),"T") + "</th>";
                trs += "<th><a href='javascript:deleteCompareModel(" + row.id + ")'>删除</a></th>";
                trs += "</tr>";
            });

            $('#' + tableId.toString()).find("tbody").empty().append(trs);
        }
    })
}

function onCreateDefinitionCustomValue(params, definition_id, project_id) {
    remote('/projects/' + project_id + '/definitions/create_custom_value?1=1' + params, "POST", {}, function (result) {
        layer.alert(result.message.toString());
        generateProductDefinitionTable('definitionFeildTable', definition_id);
    })
}

function onCreateDefinitionModule(params, project_id){
    remote('/projects/' + project_id + '/definitions/create_definition_module?1=1' + params, "POST", {}, function (result) {
        layer.alert(result.message.toString());
        generateDefinitionModuleTable('moduleTable');
    })
}

function onCreateDefinitionCustomFeild(params, project_id){
    remote('/projects/' + project_id + '/definitions/create_custom_field?1=1' + params, "POST", {}, function (result) {
        layer.alert(result.message.toString());
        generateDefinitionFieldTable('feildTable');
    })
}

function onCreateModuleField(params, project_id) {
    remote('/projects/' + project_id + '/definitions/create_module_field?1=1' + params, "POST", {}, function (result) {
        layer.alert(result.message.toString());
        generateModuleFieldTable('moduleFeildTable');
    })
}

function onCreateCompareModel(params, project_id) {
    remote('/projects/' + project_id + '/definitions/create_compare_model?1=1' + params, "POST", {}, function (result) {
        layer.alert(result.message.toString());
        generateCompareModelTable('compareModelTable');
    })
}

function getModuleFields(moduleId, project_id) {
    remote('/projects/' + project_id + '/definitions/definition_module_fields?module_id=' + moduleId, "POST", {}, function (result) {
        var fields = [];
        $.map(result.rows,function (row) {
            fields.push(row.cf_id);
        })

        $('#product_custom_field_id').val(fields).trigger("change");
    })
}

function replaceOtherString(str, removeStr) {
    return str.toString().replace(removeStr,"");
}

function refreshPage() {
    window.location.reload();
}

function hideDefinitionModule(moduleId, tableId){
    displayOrHide(false, moduleId, tableId);
}

function displayDefinitionModule(moduleId, tableId) {
    displayOrHide(true, moduleId, tableId);
}

function displayOrHide(display, moduleId, tableId, project_id) {
    var confirmContent = display ? "显示" : "隐藏";
    layer.confirm("确定要" + confirmContent + "吗？", {btn: ['取消', '确定']},
        function (cancal) {
            layer.close(cancal);
        },
        function () {
            remote("/projects/" + project_id + "/definitions/hide_definition_module", "POST", {module_id: moduleId, display: display}, function (res) {
                if (res.rows != undefined && res.rows != null) {
                    layer.msg("操作成功！");
                    generateDefinitionModuleTable(tableId);
                }
            })
        }
    );
}

function deleteModuleField(id, project_id) {
    layer.confirm("确定要删除吗？", {btn: ['取消', '确定']},
        function (cancal) {
            layer.close(cancal);
        },
        function () {
            remote('/projects/' + project_id + '/definitions/delete_module_field?id=' + id, "POST", {}, function (result) {
                layer.alert(result.message.toString());
                generateModuleFieldTable('moduleFeildTable');
            })
        }
    );
}

function deleteCustomValue(id, definition_id, project_id) {
    layer.confirm("确定要删除吗？", {btn: ['取消', '确定']},
        function (cancal) {
            layer.close(cancal);
        },
        function () {
            remote('/projects/' + project_id + '/definitions/delete_custom_value?id=' + id, "POST", {}, function (result) {
                layer.alert(result.message.toString());
                generateProductDefinitionTable('definitionFeildTable', definition_id);
            })
        }
    );
}

function deleteCompareModel(id, project_id) {
    layer.confirm("确定要删除吗？", {btn: ['取消', '确定']},
        function (cancal) {
            layer.close(cancal);
        },
        function () {
            remote('/projects/' + project_id + '/definitions/delete_compare_model?id=' + id, "POST", {}, function (result) {
                layer.alert(result.message.toString());
                generateCompareModelTable('compareModelTable');
            })
        }
    );
}

function editCustomValueAll(project_id) {
    $('#editCustomValueForm').submit();
    // remote("/projects/" + project_id + "/definitions/edit_custom_value", "POST", {fields: JSON.stringify($('#editCustomValueForm').serializeObject())}, function (result) {
    //     layer.msg(result.message.toString());
    //     history.back()
    // })
}

function isInitDataTable(tableId) {
    return $('#' + tableId).attr("class").toString().indexOf("dataTable") > -1;
}

function initDefinition(project_id) {
    layer.msg("这可能需要几分钟，请耐心等待！");
    remote('/projects/' + project_id + '/definitions/new', "GET", {}, function (result) {
        layer.alert(result.message.toString());
        refreshPage();
    })
}

// Fix menu block
(function ($) {
    $.fn.fixedMenuBlock = function (args) {
        var top = this.offset().top, timeId;
        this.css("position", "absolute");
        $(window).on('scroll', function(event) {
            if (timeId) clearTimeout(timeId);
            timeId = setTimeout(function () {
                if (($(event.target).scrollTop() + 100) >= top) {
                    this.css({top: $(event.target).scrollTop() - top + 100});
                } else {
                    this.css ({top: 1000});
                }
            }.bind(this), 200)
        }.bind(this))
    }
})(jQuery);

function dataTableEditor(tableId, opts){
    if(opts.ajax == undefined || opts.fields == undefined || opts.columns == undefined){
        layer.msg("参数错误")
    }
    else{
        var editor;
        editor = new $.fn.dataTable.Editor({
            ajax: opts.ajax,
            table: "#" + tableId,
            fields: opts.fields
        })

        initDataTable(tableId.toString(),{
            dom: "Bfrtip",
            ajax: opts.ajax,
            order: [],
            columns: opts.columns,
            select: {
                style: 'os',
                selector: 'td:first-child'
            },
            buttons: [{
                extend: 'create',editor: editor
            },{
                extend: 'edit',editor: editor
            },{
                extend: 'remove',editor: editor
            }]
        })

        $('#' + tableId.toString()).on('click', 'tbody td:not(:first-child)', function (e) {
            editor.inline(this);
        });
    }
}
/* Product Definition End */

/* Plan Begin */
function getLocalization() {
    var localizationobj = {};
    localizationobj.pagerGoToPageString = "转到页:";
    localizationobj.pagerShowRowsString = "行数:";
    localizationobj.pagerRangeString = " 中 ";
    localizationobj.pagerNextButtonString = "下一页";
    localizationobj.pagerFirstButtonString = "首页";
    localizationobj.pagerLastButtonString = "尾页";
    localizationobj.pagerPreviousButtonString = "上一页";
    localizationobj.sortAscendingString = "升序";
    localizationobj.sortDescendingString = "降序";
    localizationobj.sortRemoveString = "清除排序";
    localizationobj.firstDay = 1;
    localizationobj.decimalSeparator = ".";
    localizationobj.thousandsSeparator = ",";
    localizationobj.filterString = "高级搜索";
    localizationobj.percentsymbol = "%";
    localizationobj.currencysymbol = "$";
    localizationobj.currencysymbolposition = "before";
    localizationobj.decimalseparator = '.';
    localizationobj.thousandsseparator = ',';
    localizationobj.pagergotopagestring = "跳转页:";
    localizationobj.pagershowrowsstring = "显示行数:";
    localizationobj.pagerrangestring = " of ";
    localizationobj.pagerpreviousbuttonstring = "上一个";
    localizationobj.pagernextbuttonstring = "下一个";
    localizationobj.groupsheaderstring = "拖动一个列，然后把它放到这个列上";
    localizationobj.sortascendingstring = "升序";
    localizationobj.sortdescendingstring = "降序";
    localizationobj.sortremovestring = "移除排序";
    localizationobj.groupbystring = "分组这一列";
    localizationobj.groupremovestring = "从分组中移除";
    localizationobj.filterclearstring = "清除过滤";
    localizationobj.filterstring = "过滤";
    localizationobj.filtershowrowstring = "显示行:";
    localizationobj.filtershowrowdatestring = "显示行数据:";
    localizationobj.filterorconditionstring = "或";
    localizationobj.filterandconditionstring = "与";
    localizationobj.filterselectallstring = "(全选)";
    localizationobj.filterchoosestring = "请选择:";
    localizationobj.filterapplystring = "应用";
    localizationobj.filtercancelstring = "取消";
    localizationobj.filterstringcomparisonoperators = ['空值', '不为空值', '包含', '包含(大小写匹配)',
        '不包含', '不包含(大小写匹配)', '开始', '开始(大小写匹配)', '结尾', '结尾(大小写匹配)', '等于', '等于(大小写匹配)', '无效', '有效'];
    localizationobj.filternumericcomparisonoperators = ['等于', '不等于', '小于', '小于或等于', '大于', '大于或等于', '无效', '有效'];
    localizationobj.filterdatecomparisonoperators = ['等于', '不等于', '小于', '小于或等于', '大于', '大于或等于', '无效', '有效'];
    localizationobj.filterbooleancomparisonoperators = ['等于', '不等于'];
    localizationobj.validationstring = "输入的值无效";
    localizationobj.emptydatastring = "没有任何数据可供显示";
    localizationobj.filterselectstring = "选择过滤器";
    localizationobj.loadtext = "加载中...";
    localizationobj.clearstring = "清除";
    localizationobj.todaystring = "今天";
    localizationobj.monthViewString = "月";
    localizationobj.timelineMonthViewString = "月";
    var days = {
        // full day names
        names: ["周日", "周一", "周二", "周三", "周四", "周五", "周六"],
        // abbreviated day names
        namesAbbr: ["周日", "周一", "周二", "周三", "周四", "周五", "周六"],
        // shortest day names
        namesShort: ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
    };
    localizationobj.days = days;
    var months = {
        // full month names (13 months for lunar calendards -- 13th month should be "" if not lunar)
        names: ["一月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "十一月", "十二月", ""],
        // abbreviated month names
        namesAbbr: ["一月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "十一月", "十二月", ""]
    };
    var patterns = {
        c: "yyyy-MM-dd",
        d: "dd.MM.yyyy",
        D: "dddd, d. MMMM yyyy",
        t: "HH:mm",
        T: "HH:mm:ss",
        f: "dddd, d. MMMM yyyy HH:mm",
        F: "dddd, d. MMMM yyyy HH:mm:ss",
        M: "dd MMMM",
        Y: "MMMM yyyy"
    }
    localizationobj.patterns = patterns;
    localizationobj.months = months;
    return localizationobj;
}

function getBranchPoints(name, project_id) {
    remote('/projects/' + project_id + '/timelines/branch_points?name=' + name, "POST", {}, function (result) {
        var fields = [];
        var opts = "";
        $.map(result.rows,function (row) {
            fields.push(row.related_id);
            opts += "<option value='" + row.id +"'>" + row.plan_name + "</option>";
        })

        $('#parent_id').empty().append(opts);
        $('#parent_id').select2();
        $('#parent_id').val(fields[0]).trigger("change");
    })
}
/* Plan End */

// function getRepos(category, project_id, select_id) {
//     remote('/repos.json', 'GET', { category: category, project_id: project_id }, function(result){
//         var cat = '';
//         $.each(result, function(index, item) {
//             cat += '<option value="' + item.id + '">' + item.url + '</option>';
//         });
//         $('#' + select_id.toString()).empty().append(cat);
//         initSelect(select_id.toString());
//     })
// }

function getRepos(category, project_id, select_id) {
    $('#' + select_id).choose_remote({url: '/repos.json', text: 'url', data: { category: category, project_id: project_id }});
}

function versionApks(vid) {
    $.get('/version_releases/version_apks', {version_id: vid}, function(res){
        var apks = res["apks"];
        if(apks.length == 0) {
            if (res["flag"].toString() == "1") {
                var html_apks = "<span class='flash warning'><span class='text-danger'><b>APK信息确认提醒:</b><br />";
                html_apks += "<br />当前版本中不存在任何APK，请确认！"
                html_apks += "<br />是否继续执行发布</span>"
                html_apks += "<input type='checkbox' name='acceptApks' /><span>是</span></span>"
                $('#apks-notice').empty().append(html_apks);
            } else {
                $('#apks-notice').empty()
            }
        } else {
            var html_apks = "<span class='flash warning'><span class='text-danger'><b>APK信息确认提醒:</b><br />";
            html_apks += $.map(apks, function(apk){ return "<span>*" + apk + "</span>"; }).join("<br />")
            html_apks += "<br />该版本中以上APK未同O平台关联，无法发布到O平台项目中，是否继续执行发布！</span>"
            html_apks += "<input type='checkbox' name='acceptApks' /><span>是</span></span>"
            $('#apks-notice').empty().append(html_apks);
        }
    })
}

function addMore() {
    openLayer("添加", "460px", $('.addForm'), function () {
        if (SMValidator.validate('#addForm')) {
            remote("/my/add_favor", "POST", $('#addForm').serializeObject() ,function (res) {
                layer.msg(res.message.toString())
                if (res.success.toString() == "1") {
                    refreshPage();
                }
            })

        } else {
            layer.alert("标题或者网址不能为空！")
            return false;
        }
    })
}

function deleteApp(id){
    openConfirmDiaiog("确定要删除吗？", function () {
        remote("/my/remove_favor", "POST", {id: id} ,function (res) {
            layer.msg(res.message.toString())
            if (res.success.toString() == "1") {
                refreshPage();
            }
        })
    })
}

function searchBaidu() {
    window.open("https://www.baidu.com/s?wd=" + $(".inp-srh").val())
}