//to get this module: npm install formidable@latest


var formidable = require('formidable'),
http = require('http'),
util = require('util');


var server = http.createServer(function(req, res) {
    res.writeHead(200, {'content-type': 'application/x-plist; charset=ISO-8859-1'});
    res.end('<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict>	<key>key</key>	<string>value</string></dict></plist>');
});


server.listen(8084, function() { console.log("JSON listening on http://localhost:8084/"); });