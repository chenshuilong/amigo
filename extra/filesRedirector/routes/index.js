var express = require('express');
var router = express.Router();
var app = express();

/* GET home page. */
router.get('/', function(req, res, next) {
  var ftp = req.query[Object.keys(req.query)[0]];
  var ip  = req.headers['x-forwarded-for'] ||
            req.connection.remoteAddress ||
            req.socket.remoteAddress ||
            req.connection.socket.remoteAddress;

  ip = ip.match(/\d+\.\d+\.\d+\.\d+/)[0];

  // check ip is berijing or not
  if(res.app.locals.isBeijing(ip)){
    var bftp = res.app.locals.toBeijingFtp(ftp)
    if(res.app.locals.ftpHasFile(bftp))
      res.redirect(bftp)
    else
      res.redirect(ftp)
  } else {
    res.redirect(ftp)
  }
});

module.exports = router;

