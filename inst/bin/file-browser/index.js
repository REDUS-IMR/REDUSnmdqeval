#!/usr/bin/env node

var http = require('http');
var _ = require('lodash');
var express = require('express');
var fs = require('fs');
var path = require('path');
var util = require('util');

var program = require('commander');

function collect(val, memo) {
  if(val && val.indexOf('.') != 0) val = "." + val;
  memo.push(val);
  return memo;
}

program
  .option('-p, --port <port>', 'Port to run the file-browser. Default value is 8088')
  .option('-e, --exclude <exclude>', 'File extensions to exclude. To exclude multiple extension pass -e multiple times. e.g. ( -e .js -e .cs -e .swp) ', collect, [])
  .parse(process.argv);

var app = express();
var dir =  '/delphi/felles';
//var dir = '/ces/cruise_data'
app.set('trust proxy', true)
//app.use(express.static(dir)); //app public directory
//app.use(express.static(__dirname)); //module directory
var server = http.createServer(app);

if(!program.port) program.port = 3000;

server.listen(program.port);
console.log("Please open the link in your browser http://<YOUR-IP>:" + program.port);

app.get('/files', function(req, res) {
 var currentDir =  dir;
 var query = req.query.path || '';
 if (query) currentDir = path.join(dir, query);
 console.log("browsing ", currentDir);
 fs.readdir(currentDir, function (err, files) {
      if (err) {
        console.log(err);
	return;
      }
      if (!files) {
	console.log("Files error!");
        return;
      }
      var data = [];
      files
      .filter(function (file) {
          return true;
      }).forEach(function (file) {
        try {
                //console.log("processing ", file);
                var isDirectory = fs.statSync(path.join(currentDir,file)).isDirectory();
                if (isDirectory) {
                  data.push({ Name : file, IsDirectory: true, Path : path.join(query, file)  });
                } else {
                  var ext = path.extname(file);
                  if(program.exclude && _.contains(program.exclude, ext)) {
                    console.log("excluding file ", file);
                    return;
                  }       
                  data.push({ Name : file, Ext : ext, IsDirectory: false, Path : path.join(currentDir, file) });
                }

        } catch(e) {
          console.log(e); 
        }        
        
      });
      data = _.sortBy(data, function(f) { return f.Name });
      res.json(data);
  });
});

app.get('/', function(req, res) {
  res.redirect('lib/template.html'); 
});

app.get('/getip', function(req, res) {
  var ip = req.ip //req.headers['x-forwarded-for'] || req.connection.remoteAddress ||  req.socket.remoteAddress || req.connection.socket.remoteAddress;
  res.json(ip);
});

