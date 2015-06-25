var express     = require('express');
var app         = express();
var port        = process.env.PORT || 8080;
var multiparty  = require('multiparty');
var fs          = require('fs');

// ROUTES
// ==============================================

// sample route with a route the way we're used to seeing it

app.get('/auth', function (req, res) {
    auth(req, res);
});

app.post('auth', function (req, res) {
    auth(req, res);
});

app.get('/noauth', function (req, res) {
    res.statusCode = 200;  // OK
    res.end('cheers man');
});

app.post('/noauth', function (req, res) {
    res.statusCode = 200;  // OK
    res.end('cheers man');
});

app.get('/json', function (req, res) {
    res.writeHead(200, {'content-type': 'application/JSON; charset=ISO-8859-1'});
    res.end('{ "key": "value" }');
});

app.get('/xml', function (req, res) {
    res.writeHead(200, {'content-type': 'application/x-plist; charset=ISO-8859-1'});
    res.end('<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict>    <key>key</key>  <string>value</string></dict></plist>');
});

app.get('/multipart', function (req, res) {
    multipart(req, res);
});

app.post('/multipart', function (req, res) {
    multipart(req, res);
});

function multipart(request, response) {
        if(request.method == 'POST') {
        var form = new multiparty.Form();
        var size = '';
        var fileCount = 0;
        form.on('file', function(name, file){
            var tmp_path = file.path
            var target_path = __dirname + '/uploaded_from_unit_test/' + file.originalFilename;
            console.log(tmp_path);
            console.log(target_path);
            console.log('filename: ' + name);
            console.log('fileSize: '+ (size / 1024));
            fs.renameSync(tmp_path, target_path, function(err) {
                if(err) console.error(err.stack);
            });
            fileCount++;
        });

        form.parse(request, function(err, fields, files) {
        });
        response.writeHead(200, {'content-type': 'text/html'});
        response.end('thanks, received ' + fileCount + ' files')
    } else {
        response.writeHead(200, {'content-type': 'text/html'});
        response.end(
          '<form action="/upload" enctype="multipart/form-data" method="post">'+
          '<input type="text" name="title"><br>'+
          '<input type="file" name="upload" multiple="multiple"><br>'+
          '<input type="submit" value="Upload">'+
          '</form>'
        );
    }
}

function auth(req, res) {
    var auth = req.headers['authorization'];  // auth is in base64(username:password)  so we need to decode the base64
    console.log("Authorization Header is: ", auth);

    if(!auth) {     // No Authorization header was passed in so it's the first time the browser hit us

        // Sending a 401 will require authentication, we need to send the 'WWW-Authenticate' to tell them the sort of authentication to use
        // Basic auth is quite literally the easiest and least secure, it simply gives back  base64( username + ":" + password ) from the browser
        res.statusCode = 401;
        res.setHeader('WWW-Authenticate', 'Basic realm="Secure Area"');

        res.end('{"html": "<html><body>You shall not pass</body></html>"}');
    } else if(auth) {    // The Authorization was passed in so now we validate it

        var tmp = auth.split(' ');   // Split on a space, the original auth looks like  "Basic Y2hhcmxlczoxMjM0NQ==" and we need the 2nd part
        console.log("tmp ", tmp);
        var buf = new Buffer(tmp[1], 'base64'); // create a buffer and tell it the data coming in is base64
        var plain_auth = buf.toString();        // read it back out as a string

        console.log("Decoded Authorization ", plain_auth);

        // At this point plain_auth = "username:password"

        var creds = plain_auth.split(':');      // split on a ':'
        var username = creds[0];
        var password = creds[1];

        if((username == 'hack') && (password == 'thegibson')) {   // Is the username/password correct?

            res.statusCode = 200;  // OK
            res.end('<html><body>Congratulations you just hax0rd teh Gibson!</body></html>');
        } else {
            res.statusCode = 401; // Force them to retry authentication
            res.setHeader('WWW-Authenticate', 'Basic realm="Secure Area"');

            // res.statusCode = 403;   // or alternatively just reject them altogether with a 403 Forbidden

            res.end('{"html": "<html><body>You shall not pass</body></html>"}');
        }
    }
}

// START THE SERVER
// ==============================================
app.listen(port);
console.log('Magic happens on port ' + port);