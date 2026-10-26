import test from 'node:test';
import assert from 'node:assert/strict';
import { PoseWorkout } from '../web/pose_rules.mjs';

const hidden = () => Array.from({ length: 33 }, () => ({ x: 0.5, y: 0.5, visibility: 0 }));
const point = (x, y) => ({ x, y, visibility: 1 });

// Side-on squat: knee angle in degrees, 180 = standing.
function squat(knee) {
  const r = knee * Math.PI / 180, p = hidden();
  const hip = point(0.5 + 0.2 * Math.sin(r), 0.7 + 0.2 * Math.cos(r));
  p[27] = point(0.5, 0.9); p[25] = point(0.5, 0.7); p[23] = hip; p[11] = point(hip.x, hip.y - 0.25);
  return p;
}

function run(engine, poses, holdMs = 500) {
  const results = []; let t = 1000;
  for (const pose of poses) for (let i = 0; i < holdMs / 50; i++) { results.push(engine.update(pose, t)); t += 50; }
  return results;
}

test('squat counts a full rep and emits a rep event', () => {
  const engine = new PoseWorkout(); engine.setExercise('squat');
  const results = run(engine, [squat(180), squat(90), squat(180)]);
  assert.equal(results.at(-1).reps, 1);
  assert.equal(results.at(-1).correctReps, 1);
  assert.equal(results.filter(r => r.repEvent === 'correct').length, 1);
});

test('shallow squat is not counted and gives a depth cue', () => {
  const engine = new PoseWorkout(); engine.setExercise('squat');
  const results = run(engine, [squat(180), squat(135), squat(180)]);
  assert.equal(results.at(-1).reps, 0);
  assert.equal(engine.summary().feedbackCounts.squat_shallow, 1);
  assert.ok(results.some(r => r.feedback.some(text => text.includes('Hạ hông'))));
});
