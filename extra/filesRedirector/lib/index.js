// app's helper for views

exports.helpers = function() {
  return {
    htmlTitle: function(name) {
      var basic_name = 'Files Redirector'
      return (name == null) ? basic_name : (basic_name + ' | ' + name);
    },
    ipArea: function(ip) {
      var city;
      var citys = ['深圳', '东莞', '北京', '印度'];
      var config = {
        0: "^(18\\.|19\\.|192\\.168)",
        1: "^(10\\.15|15\\.5|16\\.6|16\\.9)",
        2: "^(10\\.1|10\\.2|10\\.5|10\\.6|10\\.7|10\\.8)",
        3: "^(10\\.20|10\\.21)"
      }

      Object.keys(config).every(function(key) {
        var reg = new RegExp(config[key]);
        return !(reg.test(ip) ? city = citys[key] : false)
      });

      return city || citys[0];
    },
    isBeijing: function(ip) {
      return new RegExp("^(10\\.1|10\\.2|10\\.5|10\\.6|10\\.7|10\\.8)").test(ip)
    },
    toBeijingFtp: function(ftp) {
      var reg    = /^.+@19\.9\.0\.162/,
          target = "ftp://log:log@10.8.0.150"

      if(/jmpzbrjcs/i.test(ftp)) { target += "/log" }
      return ftp.replace(reg, target)
    },
    ftpHasFile: function(ftp, callback) {
      var execSync = require('child_process').execSync;
      var cmd = 'curl -I ' + ftp;
      try { execSync(cmd); return true } catch (err) { return false }
    }
  }
}


