@echo off
REM ============================================================
REM  Local preview server for the Synapse Optics website.
REM
REM  Why: the site uses absolute paths like /css/style.css. Those
REM  only resolve when the pages are served over HTTP. Opening
REM  index.html by double-clicking gives you a file:// URL where
REM  /css/style.css points at C:\css\style.css — broken.
REM
REM  Usage: double-click this file. A console window stays open
REM  serving the site at http://localhost:8765. Open the URL in
REM  any browser. Close the console window to stop the server.
REM ============================================================

setlocal
cd /d "%~dp0"

echo.
echo Synapse Optics — local preview
echo Open http://localhost:8765 in your browser
echo Press Ctrl+C or close this window to stop.
echo.

node -e "const http=require('http'),fs=require('fs'),path=require('path');const root=process.cwd();const t={'.html':'text/html','.css':'text/css','.svg':'image/svg+xml','.png':'image/png','.jpg':'image/jpeg','.jpeg':'image/jpeg','.gif':'image/gif','.ico':'image/x-icon','.js':'application/javascript','.json':'application/json'};http.createServer((req,res)=>{let p=decodeURIComponent(req.url.split('?')[0]);if(p.endsWith('/'))p+='index.html';const fp=path.join(root,p);if(fs.existsSync(fp)&&fs.statSync(fp).isFile()){res.writeHead(200,{'Content-Type':t[path.extname(fp).toLowerCase()]||'application/octet-stream','Cache-Control':'no-cache'});res.end(fs.readFileSync(fp));}else{res.writeHead(404,{'Content-Type':'text/plain'});res.end('404 not found: '+p);}}).listen(8765);"

endlocal
