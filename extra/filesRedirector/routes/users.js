var express = require('express');
var router = express.Router();

/* GET users listing. */
router.get('/', function(req, res, next) {
  var ftp = "ftp://cqlog:cqlog@19.9.0.162/os_log/server.txt";
      ftp = res.app.locals.toBeijingFtp(ftp);
  var r   = res.app.locals.ftpHasFile(ftp);
  res.send(r)
});

module.exports = router;
