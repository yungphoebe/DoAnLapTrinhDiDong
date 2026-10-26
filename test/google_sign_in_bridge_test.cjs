const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

function bridge() {
  let initialization, renderOptions, renders = 0;
  const window = { google: { accounts: { id: {
    initialize: options => { initialization = options; },
    renderButton: (element, options) => { renderOptions = options; renders++; },
  } } } };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../web/google-sign-in.js'), 'utf8'), { window, document: {}, setTimeout, clearTimeout });
  return { window, initialization: () => initialization, renderOptions: () => renderOptions, renders: () => renders };
}

test('renders official button and forwards only the credential to the active screen', async () => {
  const b = bridge();
  const element = { isConnected: true };
  let received;
  await b.window.gymGoogleSignIn.render(element, 'client-id', value => { received = value; });
  assert.equal(b.initialization().client_id, 'client-id');
  assert.equal(b.initialization().auto_select, false);
  assert.equal(b.renderOptions().type, 'icon');
  b.initialization().callback({ credential: 'signed-token' });
  assert.equal(received, 'signed-token');
  element.isConnected = false;
  b.initialization().callback({ credential: 'stale-token' });
  assert.equal(received, 'signed-token');
});

test('reopening login routes callbacks to the current screen without initializing twice', async () => {
  const b = bridge();
  let oldCalls = 0, newCalls = 0;
  await b.window.gymGoogleSignIn.render({ isConnected: true }, 'client-id', () => oldCalls++);
  const original = b.initialization();
  await b.window.gymGoogleSignIn.render({ isConnected: true }, 'client-id', () => newCalls++);
  assert.equal(b.initialization(), original);
  original.callback({ credential: 'token' });
  assert.equal(oldCalls, 0);
  assert.equal(newCalls, 1);
  assert.equal(b.renders(), 2);
});

test('waits for Flutter platform view to be attached before rendering GIS', async () => {
  const b = bridge();
  const element = { isConnected: false };
  const rendering = b.window.gymGoogleSignIn.render(element, 'client-id', () => {});
  assert.equal(b.renders(), 0);
  setTimeout(() => { element.isConnected = true; }, 20);
  await rendering;
  assert.equal(b.renders(), 1);
});

test('failed Google script load can be retried', async () => {
  let attempts = 0, renders = 0;
  const window = {};
  const document = {
    createElement: () => ({ remove() {} }),
    head: { appendChild(script) {
      queueMicrotask(() => {
        if (++attempts === 1) return script.onerror();
        window.google = { accounts: { id: {
          initialize() {}, renderButton() { renders++; },
        } } };
        script.onload();
      });
    } },
  };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../web/google-sign-in.js'), 'utf8'), { window, document, setTimeout, clearTimeout });
  await assert.rejects(window.gymGoogleSignIn.render({ isConnected: true }, 'id', () => {}), /Google unavailable/);
  await window.gymGoogleSignIn.render({ isConnected: true }, 'id', () => {});
  assert.equal(renders, 1);
});
