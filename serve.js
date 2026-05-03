// Tiny static server for local preview of the Synapse Optics site.
// Run via serve.bat (Windows) or `node serve.js` (any platform).

const http = require('http');
const fs   = require('fs');
const path = require('path');

const PORT = 8765;
const root = __dirname;

const types = {
  '.html': 'text/html; charset=utf-8',
  '.css':  'text/css; charset=utf-8',
  '.svg':  'image/svg+xml',
  '.png':  'image/png',
  '.jpg':  'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif':  'image/gif',
  '.ico':  'image/x-icon',
  '.js':   'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
};

const server = http.createServer((req, res) => {
  let p = decodeURIComponent(req.url.split('?')[0]);
  if (p.endsWith('/')) p += 'index.html';

  const fp = path.join(root, p);
  if (fs.existsSync(fp) && fs.statSync(fp).isFile()) {
    res.writeHead(200, {
      'Content-Type': types[path.extname(fp).toLowerCase()] || 'application/octet-stream',
      'Cache-Control': 'no-cache',
    });
    res.end(fs.readFileSync(fp));
    console.log(`200  ${p}`);
  } else {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('404 not found: ' + p);
    console.log(`404  ${p}`);
  }
});

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`\nPort ${PORT} is already in use.`);
    console.error(`Close any other preview server and try again, or change PORT in serve.js.`);
  } else {
    console.error('\nServer error:', err.message);
  }
  process.exit(1);
});

server.listen(PORT, () => {
  console.log(`Listening on http://localhost:${PORT}`);
  console.log(`Serving from ${root}`);
  console.log(`Press Ctrl+C to stop.\n`);
});
