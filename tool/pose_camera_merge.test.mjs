import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { PoseSession } from '../web/pose_session.mjs';

function camera() {
  const elements = new Map(), listeners = {}, speech = [];
  let worker, now = 1000;
  const parent = { postMessage() {} };
  const drawing = { clearRect() {}, beginPath() {}, moveTo() {}, lineTo() {}, stroke() {}, arc() {}, fill() {} };
  const element = id => {
    if (!elements.has(id)) elements.set(id, {
      checked: true, value: 'auto', style: {}, parentElement: { style: {} },
      videoWidth: 640, videoHeight: 480, readyState: 2,
      play: async () => {}, addEventListener() {}, removeEventListener() {},
      getContext: () => drawing, textContent: ''
    });
    return elements.get(id);
  };
  const context = vm.createContext({
    window: { parent, addEventListener: (kind, listener) => { (listeners[kind] ??= []).push(listener); } },
    document: { getElementById: element, addEventListener() {} },
    location: { origin: 'http://localhost:5353' },
    navigator: { mediaDevices: { getUserMedia: async () => ({
      getTracks: () => [], getVideoTracks: () => []
    }) } },
    performance: { now: () => now }, crypto: { randomUUID: () => 'test-session' },
    URL, Date, setTimeout, clearTimeout, queueMicrotask,
    setInterval: () => 1, clearInterval() {}, requestAnimationFrame: () => 1, cancelAnimationFrame() {},
    PoseSession,
    PoseWorkout: class {
      setExercise() {} resetMotion() {}
      update() { return { tracking:true, exercise:'squat', landmarks:[], feedbackCodes:[], feedback:[], reps:2, correctReps:2, incorrectReps:0 }; }
    },
    PoseVoice: class {
      supported = true; enabled = true; hasVietnameseVoice = true;
      speak(text) { speech.push(text); } stop() {} dispose() {}
    },
    Worker: class {
      constructor() { worker = this; }
      postMessage(data) { if (data.type === 'init') queueMicrotask(() => this.onmessage({data:{type:'ready'}})); }
      terminate() {}
    }
  });
  const source = fs.readFileSync(new URL('../web/pose_camera.mjs', import.meta.url), 'utf8')
    .replace(/^import .*?;\r?\n/gm, '')
    .replaceAll('import.meta.url', '"http://localhost:5353/pose_camera.mjs"');
  vm.runInContext(source, context);
  return { element, speech, context,
    configure: fields => listeners.message.forEach(listener => listener({ origin:'http://localhost:5353', source:parent,
      data:JSON.stringify({type:'aigym:configure', exercise:'squat', ...fields}) })),
    pose: () => worker.onmessage({data:{type:'pose',landmarks:[],timestamp:now,width:640,height:480}}),
    tick: value => { now = value; }
  };
}

test('planned sets complete while Google-era Vietnamese camera guidance stays active', async () => {
  const app = camera();
  app.configure({targetSets:1,targetReps:2,restSeconds:0});
  await app.element('start').onclick();
  assert.ok(app.speech.some(text => text.includes('Bắt đầu tập luyện')));
  assert.doesNotThrow(() => app.pose());
  assert.match(app.element('status').textContent, /Đã đạt mục tiêu/);
  assert.equal(app.element('reps').textContent, 2);
});

test('rest between planned sets pauses active time and retains Vietnamese test control', async () => {
  const app = camera();
  app.configure({targetSets:2,targetReps:2,restSeconds:30});
  await app.element('start').onclick();
  assert.doesNotThrow(() => app.pose());
  app.tick(2000);
  await app.context.frame(2000);
  assert.match(app.element('feedback').textContent, /Đang nghỉ/);
  app.element('voice-test').onclick();
  assert.ok(app.speech.some(text => text.includes('Xin chào!')));
});
