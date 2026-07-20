#!/usr/bin/env node
// Lanxi SSH WebSocket proxy — web Flutter ↔ remote SSH
// Usage: node ws-proxy.mjs
// Env: PORT (default 25568), HOST (default 127.0.0.1)

import { WebSocketServer } from 'ws';
import { Client } from 'ssh2';

const PORT = parseInt(process.env.PORT || '25568', 10);
const HOST = process.env.HOST || '127.0.0.1';

const wss = new WebSocketServer({ port: PORT, host: HOST });

wss.on('connection', (ws) => {
  console.log('[lanxi] WebSocket connected');
  let ssh = null;
  let shell = null;

  ws.on('message', (data) => {
    let msg;
    try { msg = JSON.parse(data.toString()); } catch (_) { return; }

    if (msg.type === 'connect') {
      ssh = new Client();
      ssh.on('ready', () => {
        console.log('[lanxi] SSH connected');
        ws.send(JSON.stringify({ type: 'ready' }));
      });
      ssh.on('error', (err) => {
        ws.send(JSON.stringify({ type: 'error', message: err.message }));
      });
      ssh.on('close', () => ws.close());

      const opts = {
        host: msg.host, port: msg.port || 22,
        username: msg.username, readyTimeout: 10000, tryKeyboard: true,
      };
      if (msg.password) opts.password = msg.password;
      if (msg.privateKey) opts.privateKey = msg.privateKey;
      if (msg.passphrase) opts.passphrase = msg.passphrase;

      ssh.on('keyboard-interactive', (name, instructions, instructionsLang, prompts, finish) => {
        finish([msg.password || '']);
      });

      ssh.connect(opts);

    } else if (msg.type === 'exec') {
      if (!ssh) return ws.send(JSON.stringify({ type: 'error', message: 'Not connected' }));
      const timer = setTimeout(() => {
        ws.send(JSON.stringify({ type: 'exec-result', id: msg.id, exitCode: -1, stdout: '', stderr: Buffer.from('timeout').toString('base64') }));
      }, (msg.timeout || 30) * 1000);

      ssh.exec(msg.command, (err, stream) => {
        clearTimeout(timer);
        if (err) {
          return ws.send(JSON.stringify({ type: 'exec-result', id: msg.id, exitCode: -1, stdout: '', stderr: Buffer.from(err.message).toString('base64') }));
        }
        const out = [], err_ = [];
        stream.on('data', (d) => out.push(d));
        stream.stderr.on('data', (d) => err_.push(d));
        stream.on('close', (code) => {
          ws.send(JSON.stringify({ type: 'exec-result', id: msg.id, exitCode: code ?? 0, stdout: Buffer.concat(out).toString('base64'), stderr: Buffer.concat(err_).toString('base64') }));
        });
      });

    } else if (msg.type === 'stream-exec') {
      if (!ssh) return ws.send(JSON.stringify({ type: 'error', message: 'Not connected' }));
      ssh.exec(msg.command, (err, stream) => {
        if (err) return ws.send(JSON.stringify({ type: 'stream-error', id: msg.id, message: err.message }));
        stream.on('data', (d) => ws.send(JSON.stringify({ type: 'stream-data', id: msg.id, data: d.toString('base64') })));
        stream.stderr.on('data', (d) => ws.send(JSON.stringify({ type: 'stream-data', id: msg.id, data: d.toString('base64') })));
        stream.on('close', () => ws.send(JSON.stringify({ type: 'stream-done', id: msg.id })));
      });

    } else if (msg.type === 'shell') {
      if (!ssh) return ws.send(JSON.stringify({ type: 'error', message: 'Not connected' }));
      ssh.shell({ cols: msg.cols || 80, rows: msg.rows || 24 }, (err, stream) => {
        if (err) return ws.send(JSON.stringify({ type: 'error', message: err.message }));
        shell = stream;
        stream.on('data', (d) => ws.send(JSON.stringify({ type: 'data', data: d.toString('base64') })));
        stream.stderr.on('data', (d) => ws.send(JSON.stringify({ type: 'data', data: d.toString('base64') })));
        stream.on('close', () => ws.send(JSON.stringify({ type: 'close' })));
        ws.send(JSON.stringify({ type: 'ready' }));
      });

    } else if (msg.type === 'resize') {
      if (shell) shell.setWindow(msg.rows || 24, msg.cols || 80, 0, 0);

    } else if (msg.type === 'input') {
      if (shell && msg.data) shell.write(Buffer.from(msg.data, 'base64'));

    } else if (msg.type === 'ping') {
      if (ssh) {
        ssh.exec('echo pong', (err, stream) => {
          if (err) return ws.send(JSON.stringify({ type: 'pong', ok: false }));
          let d = '';
          stream.on('data', (c) => d += c.toString());
          stream.on('close', () => ws.send(JSON.stringify({ type: 'pong', ok: d.includes('pong') })));
        });
      } else {
        ws.send(JSON.stringify({ type: 'pong', ok: false }));
      }
    }
  });

  ws.on('close', () => {
    if (shell) shell.close();
    if (ssh) ssh.end();
  });
  ws.on('error', () => {});
});

console.log(`Lanxi WS proxy → ws://${HOST}:${PORT}/`);
