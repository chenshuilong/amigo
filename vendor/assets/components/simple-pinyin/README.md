simple-pinyin
=============

汉字转拼音模块，用于快速检索，可以应用在 Chaplin 的 filter 函数或者 select2 的 matcher 函
数中，功能非常简单、方便。

使用方法
-------

```
var simplePinyin = require('simple-pinyin');
simplePinyin('你好 NodeJS');
>> Object {short: "NH-NodeJS", full: "NiHao"}
```

与 Select2 整合
--------------
在 Select2 的 matcher 参数中整合 simplePinyin 后可以使用拼音，或者首字拼音对中文进行检索，
极大地提高用户体验。


```
    $.extend($.fn.select2.defaults, {
      matcher: function(term, text) {
        mod = simplePinyin(text);
        termUpperCase = term.toUpperCase();
        inFull = mod.full.toUpperCase().indexOf(termUpperCase) === 0;
        inShort = mod.short.toUpperCase().indexOf(termUpperCase) === 0;
        return (inFull || inShort);
      };
    });
```

可以参考[范例](http://xuqingkuang.github.io/simple-pinyin/)。
