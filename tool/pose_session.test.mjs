import { test } from 'node:test';
import assert from 'node:assert/strict';
import { PoseSession } from '../web/pose_session.mjs';

test('only active time is saved, retries freeze same summary and ID', () => {
  const session = new PoseSession('abc', '2026-10-16T01:00:00Z');
  session.resume(1000);
  session.pause(3500);
  session.resume(10000);
  const payload = session.finish(11500, {exercises: [{exercise:'squat',reps:1}],feedbackCounts:{}});
  assert.equal(payload.durationSeconds, 4);
  assert.equal(session.finish(99999, {exercises: []}), payload);
  session.resume(99999);
  assert.equal(session.seconds(100999), 4);
});
test('repeated resume/pause cannot inflate the timer; empty session is not savable', () => {
  const session = new PoseSession('a', '2026-10-16T00:00:00Z');
  session.resume(0); session.resume(500);
  session.pause(900); session.pause(8000);
  assert.equal(session.finish(9000, {exercises:[],feedbackCounts:{}}).durationSeconds, 0);
});
