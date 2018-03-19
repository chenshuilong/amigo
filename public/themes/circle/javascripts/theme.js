//------------------------- ADD jQuery Mobile ----------------------------------//
/*! jQuery Mobile v1.4.5 | Copyright 2010, 2014 jQuery Foundation, Inc. | jquery.org/license */

(function(e,t,n){typeof define=="function"&&define.amd?define(["jquery"],function(r){return n(r,e,t),r.mobile}):n(e.jQuery,e,t)})(this,document,function(e,t,n,r){(function(e,n){e.extend(e.support,{orientation:"orientation"in t&&"onorientationchange"in t})})(e),function(e){e.event.special.throttledresize={setup:function(){e(this).bind("resize",n)},teardown:function(){e(this).unbind("resize",n)}};var t=250,n=function(){s=(new Date).getTime(),o=s-r,o>=t?(r=s,e(this).trigger("throttledresize")):(i&&clearTimeout(i),i=setTimeout(n,t-o))},r=0,i,s,o}(e),function(e,t){function p(){var e=s();e!==o&&(o=e,r.trigger(i))}var r=e(t),i="orientationchange",s,o,u,a,f={0:!0,180:!0},l,c,h;if(e.support.orientation){l=t.innerWidth||r.width(),c=t.innerHeight||r.height(),h=50,u=l>c&&l-c>h,a=f[t.orientation];if(u&&a||!u&&!a)f={"-90":!0,90:!0}}e.event.special.orientationchange=e.extend({},e.event.special.orientationchange,{setup:function(){if(e.support.orientation&&!e.event.special.orientationchange.disabled)return!1;o=s(),r.bind("throttledresize",p)},teardown:function(){if(e.support.orientation&&!e.event.special.orientationchange.disabled)return!1;r.unbind("throttledresize",p)},add:function(e){var t=e.handler;e.handler=function(e){return e.orientation=s(),t.apply(this,arguments)}}}),e.event.special.orientationchange.orientation=s=function(){var r=!0,i=n.documentElement;return e.support.orientation?r=f[t.orientation]:r=i&&i.clientWidth/i.clientHeight<1.1,r?"portrait":"landscape"},e.fn[i]=function(e){return e?this.bind(i,e):this.trigger(i)},e.attrFn&&(e.attrFn[i]=!0)}(e,this),function(e,t,n,r){function T(e){while(e&&typeof e.originalEvent!="undefined")e=e.originalEvent;return e}function N(t,n){var i=t.type,s,o,a,l,c,h,p,d,v;t=e.Event(t),t.type=n,s=t.originalEvent,o=e.event.props,i.search(/^(mouse|click)/)>-1&&(o=f);if(s)for(p=o.length,l;p;)l=o[--p],t[l]=s[l];i.search(/mouse(down|up)|click/)>-1&&!t.which&&(t.which=1);if(i.search(/^touch/)!==-1){a=T(s),i=a.touches,c=a.changedTouches,h=i&&i.length?i[0]:c&&c.length?c[0]:r;if(h)for(d=0,v=u.length;d<v;d++)l=u[d],t[l]=h[l]}return t}function C(t){var n={},r,s;while(t){r=e.data(t,i);for(s in r)r[s]&&(n[s]=n.hasVirtualBinding=!0);t=t.parentNode}return n}function k(t,n){var r;while(t){r=e.data(t,i);if(r&&(!n||r[n]))return t;t=t.parentNode}return null}function L(){g=!1}function A(){g=!0}function O(){E=0,v.length=0,m=!1,A()}function M(){L()}function _(){D(),c=setTimeout(function(){c=0,O()},e.vmouse.resetTimerDuration)}function D(){c&&(clearTimeout(c),c=0)}function P(t,n,r){var i;if(r&&r[t]||!r&&k(n.target,t))i=N(n,t),e(n.target).trigger(i);return i}function H(t){var n=e.data(t.target,s),r;!m&&(!E||E!==n)&&(r=P("v"+t.type,t),r&&(r.isDefaultPrevented()&&t.preventDefault(),r.isPropagationStopped()&&t.stopPropagation(),r.isImmediatePropagationStopped()&&t.stopImmediatePropagation()))}function B(t){var n=T(t).touches,r,i,o;n&&n.length===1&&(r=t.target,i=C(r),i.hasVirtualBinding&&(E=w++,e.data(r,s,E),D(),M(),d=!1,o=T(t).touches[0],h=o.pageX,p=o.pageY,P("vmouseover",t,i),P("vmousedown",t,i)))}function j(e){if(g)return;d||P("vmousecancel",e,C(e.target)),d=!0,_()}function F(t){if(g)return;var n=T(t).touches[0],r=d,i=e.vmouse.moveDistanceThreshold,s=C(t.target);d=d||Math.abs(n.pageX-h)>i||Math.abs(n.pageY-p)>i,d&&!r&&P("vmousecancel",t,s),P("vmousemove",t,s),_()}function I(e){if(g)return;A();var t=C(e.target),n,r;P("vmouseup",e,t),d||(n=P("vclick",e,t),n&&n.isDefaultPrevented()&&(r=T(e).changedTouches[0],v.push({touchID:E,x:r.clientX,y:r.clientY}),m=!0)),P("vmouseout",e,t),d=!1,_()}function q(t){var n=e.data(t,i),r;if(n)for(r in n)if(n[r])return!0;return!1}function R(){}function U(t){var n=t.substr(1);return{setup:function(){q(this)||e.data(this,i,{});var r=e.data(this,i);r[t]=!0,l[t]=(l[t]||0)+1,l[t]===1&&b.bind(n,H),e(this).bind(n,R),y&&(l.touchstart=(l.touchstart||0)+1,l.touchstart===1&&b.bind("touchstart",B).bind("touchend",I).bind("touchmove",F).bind("scroll",j))},teardown:function(){--l[t],l[t]||b.unbind(n,H),y&&(--l.touchstart,l.touchstart||b.unbind("touchstart",B).unbind("touchmove",F).unbind("touchend",I).unbind("scroll",j));var r=e(this),s=e.data(this,i);s&&(s[t]=!1),r.unbind(n,R),q(this)||r.removeData(i)}}}var i="virtualMouseBindings",s="virtualTouchID",o="vmouseover vmousedown vmousemove vmouseup vclick vmouseout vmousecancel".split(" "),u="clientX clientY pageX pageY screenX screenY".split(" "),a=e.event.mouseHooks?e.event.mouseHooks.props:[],f=e.event.props.concat(a),l={},c=0,h=0,p=0,d=!1,v=[],m=!1,g=!1,y="addEventListener"in n,b=e(n),w=1,E=0,S,x;e.vmouse={moveDistanceThreshold:10,clickDistanceThreshold:10,resetTimerDuration:1500};for(x=0;x<o.length;x++)e.event.special[o[x]]=U(o[x]);y&&n.addEventListener("click",function(t){var n=v.length,r=t.target,i,o,u,a,f,l;if(n){i=t.clientX,o=t.clientY,S=e.vmouse.clickDistanceThreshold,u=r;while(u){for(a=0;a<n;a++){f=v[a],l=0;if(u===r&&Math.abs(f.x-i)<S&&Math.abs(f.y-o)<S||e.data(u,s)===f.touchID){t.preventDefault(),t.stopPropagation();return}}u=u.parentNode}}},!0)}(e,t,n),function(e){e.mobile={}}(e),function(e,t){var r={touch:"ontouchend"in n};e.mobile.support=e.mobile.support||{},e.extend(e.support,r),e.extend(e.mobile.support,r)}(e),function(e,t,r){function l(t,n,i,s){var o=i.type;i.type=n,s?e.event.trigger(i,r,t):e.event.dispatch.call(t,i),i.type=o}var i=e(n),s=e.mobile.support.touch,o="touchmove scroll",u=s?"touchstart":"mousedown",a=s?"touchend":"mouseup",f=s?"touchmove":"mousemove";e.each("touchstart touchmove touchend tap taphold swipe swipeleft swiperight scrollstart scrollstop".split(" "),function(t,n){e.fn[n]=function(e){return e?this.bind(n,e):this.trigger(n)},e.attrFn&&(e.attrFn[n]=!0)}),e.event.special.scrollstart={enabled:!0,setup:function(){function s(e,n){r=n,l(t,r?"scrollstart":"scrollstop",e)}var t=this,n=e(t),r,i;n.bind(o,function(t){if(!e.event.special.scrollstart.enabled)return;r||s(t,!0),clearTimeout(i),i=setTimeout(function(){s(t,!1)},50)})},teardown:function(){e(this).unbind(o)}},e.event.special.tap={tapholdThreshold:750,emitTapOnTaphold:!0,setup:function(){var t=this,n=e(t),r=!1;n.bind("vmousedown",function(s){function a(){clearTimeout(u)}function f(){a(),n.unbind("vclick",c).unbind("vmouseup",a),i.unbind("vmousecancel",f)}function c(e){f(),!r&&o===e.target?l(t,"tap",e):r&&e.preventDefault()}r=!1;if(s.which&&s.which!==1)return!1;var o=s.target,u;n.bind("vmouseup",a).bind("vclick",c),i.bind("vmousecancel",f),u=setTimeout(function(){e.event.special.tap.emitTapOnTaphold||(r=!0),l(t,"taphold",e.Event("taphold",{target:o}))},e.event.special.tap.tapholdThreshold)})},teardown:function(){e(this).unbind("vmousedown").unbind("vclick").unbind("vmouseup"),i.unbind("vmousecancel")}},e.event.special.swipe={scrollSupressionThreshold:30,durationThreshold:1e3,horizontalDistanceThreshold:30,verticalDistanceThreshold:30,getLocation:function(e){var n=t.pageXOffset,r=t.pageYOffset,i=e.clientX,s=e.clientY;if(e.pageY===0&&Math.floor(s)>Math.floor(e.pageY)||e.pageX===0&&Math.floor(i)>Math.floor(e.pageX))i-=n,s-=r;else if(s<e.pageY-r||i<e.pageX-n)i=e.pageX-n,s=e.pageY-r;return{x:i,y:s}},start:function(t){var n=t.originalEvent.touches?t.originalEvent.touches[0]:t,r=e.event.special.swipe.getLocation(n);return{time:(new Date).getTime(),coords:[r.x,r.y],origin:e(t.target)}},stop:function(t){var n=t.originalEvent.touches?t.originalEvent.touches[0]:t,r=e.event.special.swipe.getLocation(n);return{time:(new Date).getTime(),coords:[r.x,r.y]}},handleSwipe:function(t,n,r,i){if(n.time-t.time<e.event.special.swipe.durationThreshold&&Math.abs(t.coords[0]-n.coords[0])>e.event.special.swipe.horizontalDistanceThreshold&&Math.abs(t.coords[1]-n.coords[1])<e.event.special.swipe.verticalDistanceThreshold){var s=t.coords[0]>n.coords[0]?"swipeleft":"swiperight";return l(r,"swipe",e.Event("swipe",{target:i,swipestart:t,swipestop:n}),!0),l(r,s,e.Event(s,{target:i,swipestart:t,swipestop:n}),!0),!0}return!1},eventInProgress:!1,setup:function(){var t,n=this,r=e(n),s={};t=e.data(this,"mobile-events"),t||(t={length:0},e.data(this,"mobile-events",t)),t.length++,t.swipe=s,s.start=function(t){if(e.event.special.swipe.eventInProgress)return;e.event.special.swipe.eventInProgress=!0;var r,o=e.event.special.swipe.start(t),u=t.target,l=!1;s.move=function(t){if(!o||t.isDefaultPrevented())return;r=e.event.special.swipe.stop(t),l||(l=e.event.special.swipe.handleSwipe(o,r,n,u),l&&(e.event.special.swipe.eventInProgress=!1)),Math.abs(o.coords[0]-r.coords[0])>e.event.special.swipe.scrollSupressionThreshold&&t.preventDefault()},s.stop=function(){l=!0,e.event.special.swipe.eventInProgress=!1,i.off(f,s.move),s.move=null},i.on(f,s.move).one(a,s.stop)},r.on(u,s.start)},teardown:function(){var t,n;t=e.data(this,"mobile-events"),t&&(n=t.swipe,delete t.swipe,t.length--,t.length===0&&e.removeData(this,"mobile-events")),n&&(n.start&&e(this).off(u,n.start),n.move&&i.off(f,n.move),n.stop&&i.off(a,n.stop))}},e.each({scrollstop:"scrollstart",taphold:"tap",swipeleft:"swipe.left",swiperight:"swipe.right"},function(t,n){e.event.special[t]={setup:function(){e(this).bind(n,e.noop)},teardown:function(){e(this).unbind(n)}}})}(e,this)});
//-------------------------- NO MORE ADDING ------------------------------------//
//-------------------------- LETS DO SAME CUSTOM SCRIPT ------------------------//




 if (window.jQuery) {
  $(window).load(function(){

    if (window.devicePixelRatio > 1) {
      var images = findImagesByRegexp('contacts_thumbnail', document);

      for(var i = 0; i < images.length; i++) {
        var lowres = images[i].src;
        old_size = lowres.match(/\/(\d*)$/)[1]
        var highres = lowres.replace(/\/(\d*)$/, "/" + String(old_size*2));
        images[i].src = highres;
      }

      var images = findImagesByRegexp(/gravatar.com\/avatar.*size=\d+/, document)

      for(var i = 0; i < images.length; i++) {
        var lowres = images[i].src;
        old_size = lowres.match(/size=(\d+)/)[1]
        var highres = lowres.replace(/size=(\d+)/, "size=" + String(old_size*2));
        images[i].src = highres;
        images[i].height = old_size;
        images[i].width = old_size;
      }

      var images = findImagesByRegexp(/\/attachments\/thumbnail\/\d+$/, document)

      for(var i = 0; i < images.length; i++) {
        var lowres = images[i].src;
        var height = images[i].height
        var width = images[i].width
        var highres = lowres + "?size=" + Math.max(height, width)*2;
        if (Math.max(height, width) > 0) {
          images[i].src = highres;
          images[i].height = height;
          images[i].width = width;
        }
      }

// Sized thumbnails
      var images = findImagesByRegexp(/\/attachments\/thumbnail\/\d+\/\d+$/, document)
      for(var i = 0; i < images.length; i++) {
        var lowres = images[i].src;
        var height = images[i].height
        var width = images[i].width
        old_size = lowres.match(/\/(\d*)$/)[1]
        var highres = lowres.replace(/\/(\d*)$/, "/" + String(old_size*2));
        images[i].src = highres;
        if (Math.max(height, width) > 0) {
          images[i].src = highres;
          images[i].height = height;
          images[i].width = width;
        }
      }

// People avatars
      var images = findImagesByRegexp(/people\/avatar.*size=\d+$/, document)

      for(var i = 0; i < images.length; i++) {
        var lowres = images[i].src;
        old_size = lowres.match(/size=(\d+)$/)[1]
        var highres = lowres.replace(/size=(\d+)$/, "size=" + String(old_size*2));
        images[i].src = highres;
      }


    }
  });
} else {
  document.observe("dom:loaded", function() {
    if (window.devicePixelRatio > 1) {
      var images = findImagesByRegexp('thumbnail', document);

      for(var i = 0; i < images.length; i++) {
        var lowres = images[i].src;
        old_size = lowres.match(/size=(\d*)$/)[1]
        var highres = lowres.replace(/size=(\d*)$/, "size=" + String(old_size*2));
        images[i].src = highres;
      }

      var images = findImagesByRegexp(/gravatar.com\/avatar.*size=\d+/, document)

      for(var i = 0; i < images.length; i++) {
        var lowres = images[i].src;
        old_size = lowres.match(/size=(\d+)/)[1]
        var highres = lowres.replace(/size=(\d+)/, "size=" + String(old_size*2));
        images[i].src = highres;
        images[i].height = old_size;
        images[i].width = old_size;
      }
    }

  });
}

function findImagesByRegexp(regexp, parentNode) {
   var images = Array.prototype.slice.call((parentNode || document).getElementsByTagName('img'));
   var length = images.length;
   var ret = [];
   for(var i = 0; i < length; ++i) {
      if(images[i].src.search(regexp) != -1) {
         ret.push(images[i]);
      }
   }
   return ret;
};


//Work with cookie
function setCookie(name, value, options) {
  options = options || {};

  var expires = options.expires;

  if (typeof expires == "number" && expires) {
    var d = new Date();
    d.setTime(d.getTime() + expires*1000);
    expires = options.expires = d;
  }
  if (expires && expires.toUTCString) {
  	options.expires = expires.toUTCString();
  }

  value = encodeURIComponent(value);

  var updatedCookie = name + "=" + value;

  for(var propName in options) {
    updatedCookie += "; " + propName;
    var propValue = options[propName];
    if (propValue !== true) {
      updatedCookie += "=" + propValue;
     }
  }

  document.cookie = updatedCookie;
}

function getCookie(name) {
  var matches = document.cookie.match(new RegExp(
    "(?:^|; )" + name.replace(/([\.$?*|{}\(\)\[\]\\\/\+^])/g, '\\$1') + "=([^;]*)"
  ));
  return matches ? decodeURIComponent(matches[1]) : undefined;
}



function deleteCookie(name) {
  setCookie(name, "", { expires: -1 })
}


$(document).ready(function () {
	var burger_height;
	var submenu_sum_width;
	var topmenu_sum_width;
	var overwidthed_flag = false;
	var overwidthed_height;
	var is_sidebar_minimized = getCookie('sidebar'); //Получаем из куки текущее состояние сайдбара

	var acc_plus_logg;

    var ani_time = 500;	// Время выполнения анимации (скорость произвольной анимации считается в X*ani_time)
	var cookie_life = 3600*24*50; // Время жизни куки
	var sidebar = 0; //Ширина кусочка сайдбара в процентах

	var qs_start_width; // Стартовая ширина квик-сёрча

	var $scwid = $(window).width();


	//Перемещение mm-menu для создания плавающей менюшки
	//Код перенесен в самое начало выполняемого скрипта
		$('#main-menu').html( '<div class="main_menu">'+ $('#main-menu').html() + '</div>');
		$('#main-menu .main_menu ul li').each(function(){
				submenu_sum_width += $(this).outerWidth();
				if( submenu_sum_width > $('.main_menu').outerWidth() - 2){
					$(this).addClass('overwidth');
				}
				else{
					$(this).removeClass('overwidth');
				}
		});

	$('#context-menu').remove();
	$('body').append('<div id="context-menu" style="display: none;"></div>');


/*SUB_FUNCTIONS FOR CALC POSITION*/
function redraw_sidebar(){

}


	/********************CALC_POSITION*************************************/
function calc_position(){
		$scwid = $(window).width();
		//redraw_sidebar();


		if( burger_height > 0 ) { $('.burger').css('height', '0px'); $('.burger_controller ').removeClass('opened'); }


		//Просчитываем суммарную ширину всех дочек субменюшки - если она больше родителя - добавляем магию

		submenu_sum_width = 0;
		var sm_delta = 2;

		$('#main-menu .main_menu ul li').each(function(){
			submenu_sum_width += $(this).outerWidth();
			if( submenu_sum_width > $('.main_menu').outerWidth() - sm_delta){
				$(this).addClass('overwidth');
			}
			else{
				$(this).removeClass('overwidth');
			}
		});
		$('.mm_burger').html('');
		if(submenu_sum_width > $('.main_menu').outerWidth()- sm_delta)
			{
				if(!overwidthed_flag){
					overwidthed_flag = true;
					$('.main_menu').before('<div class="mm_burger_caller"></div>');
					$('#main-menu').append('<ul class="mm_burger"></ul>');
				}
				$('.main_menu ul li.overwidth').each(function(){
					$(this).clone().removeClass('overwidth').appendTo('.mm_burger');
					//Если менюшка открыта во время рисайза
					if( $('.mm_burger_caller').hasClass('opened') ){
						$('.mm_burger').css({'height': $('.mm_burger li').size()*$('.mm_burger li').outerHeight() });
					}
				})
			}
		else{
			$('.mm_burger').remove();
			$('.mm_burger_caller').remove();
			overwidthed_flag = false;
		}

		$('.ellipsis').remove();
		$('.fmm_wrapper').remove();

		topmenu_sum_width = 0;
		$('.burger_clone').css({'display': 'block'});
		$('.burger_clone li').each(function(){
			topmenu_sum_width += $(this).outerWidth();

			if(topmenu_sum_width > $('#top-menu').outerWidth() - acc_plus_logg){$('.header_elements').addClass('first_stage'); var acc_plus_logg_fs = $('#account').outerWidth(true) + $('#loggedas').outerWidth(true);}
			else {$('.header_elements').removeClass('first_stage');}

			//if(topmenu_sum_width > $('.header_elements').innerWidth() - 110 - 135 - 80 ){
			//if(topmenu_sum_width > $('.header_elements').innerWidth() - $('#account').outerWidth(true) - $('#loggedas').outerWidth(true) - 80 ){
			if(topmenu_sum_width > $('.header_elements').innerWidth() - acc_plus_logg_fs - 80 ){
				$(this).addClass('overwidth');
				$('.ellipsis').remove();
				$('.burger_clone').append('<div class="ellipsis"><a href="#">...</a></div>');
			}
			else {
				$(this).removeClass('overwidth');
				$('.ellipsis').remove();
			}

			$('.ellipsis').tap(function(){
				if(	$('.fmm_wrapper').size() == 0	){
					$('.burger_clone').append('<div class="fmm_wrapper"><ul></ul></div>');
					$('.burger_clone li.overwidth').each(function(){
					$(this).clone(true).removeClass('overwidth').appendTo('.fmm_wrapper ul');
					});
				}
				else
				{
					$('.fmm_wrapper').remove();
				}
			});
		});

		//Схлопывание H1
		if ( $('#header').innerWidth() - qs_start_width - 60 < $('#header h1').outerWidth() ){
			$('#quick-search').addClass('adapted');
		}
		else{
			$('#quick-search').removeClass('adapted');
		}

		//Пересчет новой ширины
		$('.sidebar_wrapper').css('min-width', $('BODY').outerWidth()*0.25-31 );

		$nmh = $(window).height() - $('#header').outerHeight(true) - $('#top-menu').outerHeight(true) - $('#footer').outerHeight(true);
		//$('#main').css({'min-height': $nmh});
		//$('#content').css({'min-height':'100%'});
		$('#content').css({'min-height': $nmh});

	}

/***************CALC_POSITION END****************************/



	//Аппендим viewport для скейла на мобилах
	$('head').append('<meta name="viewport" content="width=device-width, initial-scale=1.0">');


	//Работа с бургером
    $('#top-menu').children('ul').addClass('burger');
    $('#top-menu').prepend('<div class="burger_controller_wrapper"><a href="#" class="burger_controller"></a></div>');
	  $('.burger').clone().removeClass('burger').addClass('burger_clone').insertBefore('#account');
	burger_height = $('.burger').outerHeight();
    $('.burger').css('height', '0px');
	$('.burger_controller_wrapper').css('display', 'none');

	//Подсказки для немобил в хедере
    $('#account a').each(function(){
        this_text = $(this).text();
        $(this).attr('title', this_text);
    });

	$('#main-menu').on('tap', '.mm_burger_caller', function(){
			if ( $('.mm_burger_caller').hasClass('opened') ){
				$('.mm_burger').animate({'height':'0px'})
				$('.mm_burger_caller').removeClass('opened');
			}
			else
			{
				$('.mm_burger').animate({'height': $('.mm_burger li').size()*$('.mm_burger li').outerHeight() });
				$('.mm_burger_caller').addClass('opened');
			}
	});

	//Тап по бургер-коллеру открывает и сворачивает менюшку
    $('#top-menu .burger_controller').on('tap', function(){
        var burger = '#top-menu .burger';
        if( $(this).hasClass('opened') ){ $(burger).animate({"height":"0px"}, ani_time); $(this).removeClass('opened'); }
        else { $(burger).animate({"height":burger_height+"px"}, ani_time); $(this).addClass('opened'); }
		return false;
    });


	//Костыляки
	//Перемещаем все элементы хедера в один блок
	$('#top-menu').prepend('<div class="header_elements"></div>');
	$('.burger_controller_wrapper').appendTo('.header_elements');
		$('.burger_clone').appendTo('.header_elements');
	$('#account').appendTo('.header_elements');
	$('#loggedas').appendTo('.header_elements');

	acc_plus_logg = $('#account').outerWidth() + $('#loggedas').outerWidth() + 60;


	//Новая версия свертывания сайдбара
	//Если сайдбар присутствует на странице
	if( !$('#sidebar').children().length == 0 ){
		//Подготовка DOM'а
		//Ставим полоску для свайпа (она же отрабатывает как куки_сеттер)
			//$('#main').append('<div class="sidebar_caller"></div>');
			$('#wrapper2').append('<div class="sidebar_caller"></div>');

		//Закидываем содержимое сайда в обертку, которая позволит не изменять видимый контент при свайпе
		var sidebar_size = $('#sidebar').outerWidth() - 30;
		//Состояния в зависимости от стейта куки
		if(is_sidebar_minimized == 'true' || typeof is_sidebar_minimized === 'undefined'){
			//Если кука еще не установлена ИЛИ если стейт сайда установлен в true
			$('#sidebar').addClass('opened');
			$('#content').css('width', '75%');
			$('#sidebar').css('width', '25%');
		}
		else{
			//Если сайд должен быть свернут на старте загрузки
			//$('.sidebar_caller').css({'right':'0%'});
			$('.sidebar_caller').addClass('opened');
			$('#sidebar').width(0);
			$('#content').css('width', '100%');
		}

		$('#sidebar').html( '<div class="sidebar_wrapper" style="min-width: '+ sidebar_size +'px">' + $('#sidebar').html() + '</div>' );
		//Крестик
		$('.sidebar_wrapper').prepend('<div class="sidebar_closer"></div>');
		$('.sidebar_closer').tap(function(){
			swipe_sidebar();
		});
		//end-крестик




		$('.sidebar_caller').tap(function(){
			swipe_sidebar();
		});

		function swipe_sidebar(){
			if(!$('#sidebar').hasClass('opened')){
				$('#sidebar').addClass('opened');
				$('.sidebar_caller').removeClass('opened');

				$('#sidebar').animate({'width':'25%'}, ani_time/2, 'linear');
				//$('.sidebar_caller').animate({'right':'25%'}, ani_time/2, 'linear');
				$('#content').animate({'width':'75%'}, ani_time/2, 'linear', function(){

				});
				deleteCookie('sidebar');
				setCookie('sidebar', true, {'expires': cookie_life, 'path': '/'});
			}
			else{
				$('#sidebar').animate({'width':'0%'}, ani_time/2, 'linear');
				//$('.sidebar_caller').animate({'right':'0%'}, ani_time/2, 'linear');
				$('#content').animate({'width':'100%'}, ani_time/2, 'linear', function(){
					$('#sidebar').removeClass('opened');
					$('.sidebar_caller').addClass('opened');
				});
				deleteCookie('sidebar');
				setCookie('sidebar', false, {'expires': cookie_life, 'path': '/'});
			}
		}

	}

	if( $('#header h1').html().length < 1 ){ $('#header h1').html('&nbsp;'); }
	qs_start_width = $('#quick-search').outerWidth();

	//Попытка подгрузки
	$('#content').append('<div id="content2"></div>');
	$('#content2').load();

	//После выполнения последнего изменения на странице нужно произвести пересчет ширин и подгон
	calc_position();

	//После рисайза и смены ориентации делается то же самое
    $(window).resize(function(){
        calc_position();
    });

	$( window ).on( "orientationchange", function( event ) {
		calc_position();
	});



	/*
	//Под аяксовую подгрузку страничек
	$('#header a, #top-main a').click(function(){
		console.log('click!');
		console.log('click2!');
         url = $(this).attr('href');
         if(url != window.location){
             window.history.pushState(null, null, url);
         }
         loadContent();
         return false;
     });
	*/

});

/*
var url;
function loadContent() {
	$('#main').append("<div id='content'/>");
	$.ajax({
		dataType: 'html',
		url: location.origin + url,
		success: function(data){
			var $response=$(data);
			var content = $response.find('#main').html();
			if ($response.filter('#wrapper').length == 0) {
				$('#content').html(data);
			} else {
				$('#main').html(content);
			}

			var bodyClass = data.match('<body class="(.*)">');
			var menuClass = data.match('<div id="main" class="(.*)">');
			console.log(menuClass[1]);
			console.log(bodyClass[1]);

			$('body').attr('class',bodyClass[1]);
			var menu = $response.find('#main-menu').html();
			if ($('#header').find('#main-menu').length == 0) {
				$('#header').append("<div id='main-menu'>");
			}
			$('#main').attr("class",menuClass[1]);

			$('#main-menu').html(menu);
			if (!$("#main").hasClass("nosidebar")){
				$("#content").append("<div class='toggleSidebar_btn'></div>")
			}
		},
		beforeSend: function (request)
		{
			request.setRequestHeader("X-Requested-With", 'test');
		}
	});

};
window.onpopstate = function () {
	url = window.location.pathname;
	loadContent();
};
*/