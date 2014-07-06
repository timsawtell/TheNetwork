var http = require('http');
var multiparty = require('multiparty');
var fs = require('fs');

http.createServer(function(request, response) {
    if(request.method == 'POST') {
        var form = new multiparty.Form();
        var size = '';
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
        });

        form.parse(request, function(err, fields, files) {
            response.writeHead(200, {'content-type': 'text/html'});
            response.end()
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