var http = require('http');
var querystring = require('querystring');
var multiparty = require('multiparty');
var util = require('util');

function processPost(request, response, callback) {
    var queryData = "";
    if(typeof callback !== 'function') return null;

    if(request.method == 'POST') {
        request.on('data', function(data) {
            queryData += data;
            if(queryData.length > 1e6) {
                queryData = "";
                response.writeHead(413, {'Content-Type': 'text/plain'}).end();
                request.connection.destroy();
            }
        });

        request.on('end', function() {
            request.post = querystring.parse(queryData);
            callback();
        });

    } else {
        response.writeHead(405, {'Content-Type': 'text/plain'});
        response.end();
    }
}

http.createServer(function(request, response) {
    if(request.method == 'POST') {
        var form = new multiparty.Form();
        form.parse(request, function(err, fields, files) {
          console.log(util.inspect({fields: fields, files: files}));
        });
        processPost(request, response, function() {
            console.log(request.post);
            // Use request.post here
            
            response.writeHead(200, "OK", {'Content-Type': 'text/plain'});
            response.end();
        });
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

}).listen(8082);