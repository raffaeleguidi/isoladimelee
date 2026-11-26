// Server statico minimale per il build Web di Godot.
// - MIME corretti (.wasm, .pck)
// - gzip al volo per wasm/pck/js (il wasm passa da ~38 MB a ~9 MB)
// - header COOP/COEP (non indispensabili per il build "nothreads", ma sicuri)

import http from "node:http";
import { createReadStream, statSync } from "node:fs";
import { extname, join, normalize } from "node:path";
import { createGzip } from "node:zlib";
import { fileURLToPath } from "node:url";
import { dirname } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, "..", "build", "web");
const PORT = Number(process.env.PORT || 8090);

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".wasm": "application/wasm",
  ".pck": "application/octet-stream",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".json": "application/json",
  ".css": "text/css; charset=utf-8",
  ".wav": "audio/wav",
};

const GZIP = new Set([".wasm", ".pck", ".js", ".html", ".json", ".svg"]);

const server = http.createServer((req, res) => {
  const urlPath = decodeURIComponent((req.url || "/").split("?")[0]);
  let rel = normalize(urlPath).replace(/^(\.\.[/\\])+/, "");
  if (rel === "/" || rel === "\\" || rel === ".") rel = "index.html";
  const file = join(ROOT, rel);

  let st;
  try {
    st = statSync(file);
    if (!st.isFile()) throw new Error("not a file");
  } catch {
    res.writeHead(404, { "Content-Type": "text/plain" });
    res.end("not found: " + rel);
    return;
  }

  const headers = {
    "Content-Type": MIME[extname(file)] || "application/octet-stream",
    "Cross-Origin-Opener-Policy": "same-origin",
    "Cross-Origin-Embedder-Policy": "require-corp",
    "Cache-Control": "no-cache",
    "Accept-Ranges": "none",
  };

  const acceptsGzip = /\bgzip\b/.test(req.headers["accept-encoding"] || "");
  if (acceptsGzip && GZIP.has(extname(file))) {
    headers["Content-Encoding"] = "gzip";
    headers["Vary"] = "Accept-Encoding";
    res.writeHead(200, headers);
    createReadStream(file).pipe(createGzip({ level: 6 })).pipe(res);
    return;
  }

  headers["Content-Length"] = st.size;
  res.writeHead(200, headers);
  createReadStream(file).pipe(res);
});

server.listen(PORT, "127.0.0.1", () => {
  console.log(`POC served at http://127.0.0.1:${PORT}/  (root: ${ROOT})`);
});
