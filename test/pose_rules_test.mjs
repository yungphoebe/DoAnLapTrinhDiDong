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

function shoulderPress(extended, rightExtended = extended) {
  const p = hidden();
  for (const side of [0, 1]) {
    const up = side === 0 ? extended : rightExtended;
    const sign = side === 0 ? -1 : 1, x = side === 0 ? .4 : .6;
    p[11+side] = point(x, .45);
    p[13+side] = up ? point(x + sign*.02, .28) : point(x + sign*.15, .45);
    p[15+side] = up ? point(x + sign*.04, .11) : point(x + sign*.15, .25);
  }
  return p;
}

test('pushup counts with shoulder, arms, hip and ankle but no knee', () => {
  function pushup(degrees) {
    const p=hidden(), r=degrees*Math.PI/180;
    p[11]=point(.2,.5); p[23]=point(.5,.5); p[27]=point(.8,.5);
    p[13]=point(.2,.65); p[15]=point(.2+.15*Math.sin(r),.65-.15*Math.cos(r));
    return p;
  }
  const engine=new PoseWorkout(); engine.setExercise('pushup');
  assert.equal(run(engine,[pushup(180),pushup(90),pushup(180)]).at(-1).correctReps,1);
});

test('shoulder press counts two rack-overhead-rack cycles with wrists above shoulders', () => {
  const engine = new PoseWorkout(); engine.setExercise('shoulderPress');
  const results = run(engine, [shoulderPress(false), shoulderPress(true), shoulderPress(false), shoulderPress(true), shoulderPress(false)]);
  assert.equal(results.at(-1).correctReps, 2);
  assert.equal(results.at(-1).exercise, 'shoulderPress');
});

test('shoulder press rejects static, one-arm and low-confidence movement', () => {
  const low = shoulderPress(true).map(p => ({...p, visibility: .1}));
  for (const poses of [
    [shoulderPress(true)],
    [shoulderPress(false), shoulderPress(true, false), shoulderPress(false)],
    [shoulderPress(false), low, shoulderPress(false)],
  ]) {
    const engine = new PoseWorkout(); engine.setExercise('shoulderPress');
    assert.equal(run(engine, poses).at(-1).reps, 0);
  }
  const engine = new PoseWorkout(); engine.setExercise('shoulderPress');
  assert.equal(run(engine, [low]).at(-1).tracking, false);
});

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
