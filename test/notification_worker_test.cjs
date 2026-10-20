const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');

function worker(state, windows = []) {
  const handlers = {}, displayed = [], opened = [];
  const scope = {
    importScripts() {}, URL, URLSearchParams,
    gymNotificationStore: {async read() {return state;}},
    self: {
      addEventListener(type, listener) {handlers[type] = listener;},
      registration: {scope: 'http://localhost:5353/notification-push/', async showNotification(title, options) {displayed.push({title, options});}},
      clients: {async matchAll() {return windows;}, async openWindow(url) {opened.push(url);}}
    }
  };
  vm.runInNewContext(fs.readFileSync('web/notification-worker.js', 'utf8'), scope);
  async function dispatch(type, event) {let done; handlers[type]({...event, waitUntil(value) {done = value;}}); await done;}
  return {displayed, opened, dispatch};
}
test('push is displayed once with its stable event tag', async () => {
  const w = worker({owner: 'a', sessionId: 'session-a', enabled: {water: true}});
  await w.dispatch('push', {data: {json: () => ({sessionId: 'session-a', kind: 'water', id: 'event-1', title: 'Water', body: 'Reminder'})}});
  assert.equal(w.displayed.length, 1); assert.equal(w.displayed[0].options.tag, 'aigym-event-1');
  assert.equal(w.displayed[0].options.data.owner, 'a');
});
test('disabled kinds and old account sessions are discarded', async () => {
  const w = worker({owner: 'b', sessionId: 'session-b', enabled: {water: false}});
  for (const sessionId of ['session-a','session-b'])
    await w.dispatch('push', {data: {json: () => ({sessionId, kind: 'water', id: 'old'})}});
  assert.equal(w.displayed.length, 0);
});
test('click opens only the same-origin application with the allowed kind', async () => {
  const w = worker({owner: 'a'});
  await w.dispatch('notificationclick', {notification: {close() {}, data: {owner: 'a', kind: 'weekly', id: '1'}}});
  assert.equal(w.opened.length, 1);
  const url = new URL(w.opened[0]); assert.equal(url.origin,'http://localhost:5353');
  assert.match(url.hash,/notification-open/); assert.match(url.hash,/kind=weekly/);
});
test('click cannot open a previous account notification', async () => {
  const w = worker({owner: 'b'});
  await w.dispatch('notificationclick', {notification: {close() {}, data: {owner:'a', kind:'water'}}});
  assert.equal(w.opened.length, 0);
});
