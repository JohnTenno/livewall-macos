// Run with node scripts/test-web-media.cjs. Exercises the actual injected script without WebKit/GPU.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const swift = fs.readFileSync(path.join(__dirname, '../Sources/Livewall/Rendering/WebRenderer.swift'), 'utf8');
const source = swift.split('private static func mediaScript(muted: Bool) -> String {')[1]
  .split('"""')[1].replace('\\(muted)', 'true');
let mutation, documentScans = 0;
const listeners = {};
const media = (muted = false) => ({muted, matches: () => true, querySelectorAll: () => []});
const first = media(), authoredMuted = media(true);
const document = {
  querySelectorAll() { documentScans++; return [first, authoredMuted]; },
  addEventListener(type, cb) { listeners[type] = cb; },
};
const window = {addEventListener(type, cb) { listeners[type] = cb; }};
const messages = [];
const child = {postMessage(message) { messages.push(message); }};
vm.runInNewContext(source, {
  document, window, parent: window, frames: [child],
  MutationObserver: class { constructor(cb) { mutation = cb; } observe() {} },
});
mutation([{addedNodes: [first, authoredMuted, {}]}]);
assert.equal(first.muted, true);
assert.equal(documentScans, 0, 'ordinary mutations must not rescan the document');
const nested = media();
mutation([{addedNodes: [{querySelectorAll: () => [nested]}]}]);
assert.equal(nested.muted, true, 'nested media must be muted');
listeners.message({source: window, data: {livewallMuted: false}});
assert.equal(first.muted, false);
assert.equal(authoredMuted.muted, true, 'preserve the page\'s own mute setting');
assert.equal(messages.at(-1).livewallMuted, false);
const scans = documentScans;
listeners.message({source: {}, data: {livewallMuted: true}});
assert.equal(documentScans, scans, 'ignore unrelated senders');
listeners.message({source: child, data: {livewallRequestMute: true}});
assert.equal(messages.at(-1).livewallMuted, false, 'new subframes get the current mute state');
listeners.message({source: window, data: {livewallMuted: true}});
const later = media();
listeners.play({target: later});
assert.equal(later.muted, true);
console.log('OK: 9 web media checks');
