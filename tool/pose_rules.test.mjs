import test from 'node:test';
import assert from 'node:assert/strict';
import { PoseWorkout } from '../web/pose_rules.mjs';

function pose(kind, active = false, bad = false) {
  const p = Array.from({length:33}, () => ({x:0.5,y:0.5,z:0,visibility:1}));
  const put = (i,x,y) => Object.assign(p[i],{x,y});
  for (const offset of [0,1]) {
    const dx = offset * (kind === 'jumpingJack' ? 0.2 : 0.025);
    if (kind === 'pushup') {
      put(11+offset,0.3,0.3); put(23+offset,0.55,bad ? 0.5 : 0.3); put(27+offset,0.85,0.3);
      put(13+offset,0.3,0.5); put(15+offset,active ? 0.5 : 0.3,active ? 0.5 : 0.7);
      put(25+offset,0.7,0.3);
    } else {
      const x = 0.4+dx;
      put(11+offset,x + (bad ? 0.2 : 0),active && kind==='squat' ? 0.35 : 0.2);
      put(23+offset,x,active && kind==='squat' ? 0.65 : 0.5);
      put(25+offset,x+(active && kind==='squat' ? 0.2 : 0),0.65);
      put(27+offset,kind==='jumpingJack' && active ? (offset ? 0.85 : 0.15) : x,0.9);
      put(13+offset,x,0.45); put(15+offset,x,kind==='jumpingJack' && active && !bad ? 0.05 : 0.55);
    }
  }
  return p;
}
function hold(w,p,start,duration=600) {
  let result;
  for(let t=start;t<=start+duration;t+=100) result=w.update(p,t);
  return result;
}
function cycle(w,kind,start=0,bad=false) {
  hold(w,pose(kind),start);
  hold(w,pose(kind,true,bad),start+700);
  return hold(w,pose(kind),start+1400);
}
for (const kind of ['squat','pushup','jumpingJack']) {
  test(`${kind}: auto detects and counts one completed cycle only`,()=>{
    const w=new PoseWorkout(); const result=cycle(w,kind);
    assert.equal(result.exercise,kind); assert.equal(result.reps,1); assert.equal(result.correctReps,1);
    assert.equal(hold(w,pose(kind),2100,2000).reps,1);
    assert.equal(w.summary().exercises.find(e=>e.exercise===kind).reps,1);
  });
}
test('partial cycle, jitter and too-fast motion do not count',()=>{
  const w=new PoseWorkout(); w.setExercise('squat');
  hold(w,pose('squat',true),0); hold(w,pose('squat'),700);
  assert.equal(w.summary().exercises.length,0);
  for(let t=1400;t<2000;t+=50) w.update(pose('squat',t%100===0),t);
  assert.equal(hold(w,pose('squat'),2000).reps,0);
});
test('missing, low confidence, offscreen and collapsed joints discard partial cycle',()=>{
  for(const invalid of [null,pose('squat')]) {
    const w=new PoseWorkout(); w.setExercise('squat');
    hold(w,pose('squat'),0); hold(w,pose('squat',true),700);
    if(invalid) {
      invalid[25].visibility=invalid[26].visibility=0.1;
    }
    assert.equal(w.update(invalid,1400).tracking,false);
    assert.equal(hold(w,pose('squat'),1500).reps,0);
  }
  for(const mutate of [p=>p[25].x=p[26].x=2,p=>p[25].x=p[26].x=NaN,p=>{Object.assign(p[25],p[23]);Object.assign(p[26],p[24]);}]) {
    const w=new PoseWorkout(); w.setExercise('squat'); const p=pose('squat'); mutate(p);
    assert.equal(w.update(p,0).tracking,false);
  }
});
function visibleSide(kind, active, side) {
  const p=pose(kind,active);
  for(const i of [11,13,15,23,25,27]) p[i+1-side].visibility=0.1;
  return p;
}
for(const kind of ['squat','pushup']) for(const side of [0,1]) {
  test(`${kind} counts with only the ${side ? 'right' : 'left'} side visible`,()=>{
    const w=new PoseWorkout();
    hold(w,visibleSide(kind,false,side),0);
    const active=hold(w,visibleSide(kind,true,side),700);
    assert.equal(active.tracking,true); assert.equal(active.exercise,kind);
    const result=hold(w,visibleSide(kind,false,side),1400);
    assert.equal(result.reps,1); assert.equal(result.correctReps,1);
  });
}
test('squat does not depend on visible wrists or elbows',()=>{
  const w=new PoseWorkout(); w.setExercise('squat');
  const samples=[pose('squat'),pose('squat',true),pose('squat')];
  for(const p of samples) for(const i of [13,14,15,16]) p[i].visibility=0;
  hold(w,samples[0],0); hold(w,samples[1],700);
  assert.equal(hold(w,samples[2],1400).reps,1);
});
test('changing visible side discards an unfinished cycle and preserves previous totals',()=>{
  const w=new PoseWorkout(); cycle(w,'squat');
  hold(w,visibleSide('squat',true,0),2100);
  assert.equal(hold(w,visibleSide('squat',false,1),2800).reps,1);
  hold(w,visibleSide('squat',true,1),3500);
  assert.equal(hold(w,visibleSide('squat',false,1),4200).reps,2);
});
test('jumping jack requires both sides, and neither usable side is rejected',()=>{
  const jack=new PoseWorkout(); jack.setExercise('jumpingJack');
  assert.equal(jack.update(visibleSide('jumpingJack',false,0),0).tracking,false);
  const p=pose('pushup'); p[15].visibility=p[16].visibility=0.1;
  const pushup=new PoseWorkout(); pushup.setExercise('pushup');
  assert.equal(pushup.update(p,0).tracking,false);
});
test('mode switch and reset discard partial motion but retain totals',()=>{
  const w=new PoseWorkout(); cycle(w,'squat');
  hold(w,pose('squat',true),2100); w.setExercise('pushup');
  assert.equal(hold(w,pose('pushup'),2800).reps,1);
  w.resetMotion(); assert.equal(cycle(w,'pushup',3500).reps,2);
  assert.throws(()=>w.setExercise('unknown'),/exercise/i);
});
test('bad form counts an incorrect rep and one feedback episode, not frames',()=>{
  const w=new PoseWorkout(); w.setExercise('pushup');
  const result=cycle(w,'pushup',0,true);
  assert.equal(result.reps,1); assert.equal(result.incorrectReps,1); assert.equal(result.correctReps,0);
  assert.equal(w.summary().feedbackCounts.pushup_body_line,1);
});
test('aspect ratio correction produces the same angles in pixel space',()=>{
  const p=pose('squat',true); const stretched=p.map(v=>({...v,x:v.x/2}));
  const a=new PoseWorkout(),b=new PoseWorkout(); a.setExercise('squat'); b.setExercise('squat');
  assert.ok(Math.abs(a.update(p,0).angle-b.update(stretched,0,2,1).angle)<0.001);
});
test('long camera gaps and reversed timestamps cannot finish a previous rep',()=>{
  for(const t of [3000,100]) {
    const w=new PoseWorkout(); w.setExercise('squat');
    hold(w,pose('squat'),0); hold(w,pose('squat',true),700);
    assert.equal(hold(w,pose('squat'),t).reps,0);
  }
});
test('automatic exercise switch discards active motion',()=>{
  const w=new PoseWorkout(); hold(w,pose('squat'),0); hold(w,pose('squat',true),700);
  assert.equal(hold(w,pose('pushup'),1400).reps,0);
  hold(w,pose('pushup',true),2100);
  assert.equal(hold(w,pose('pushup'),2800).reps,1);
});
test('a full but implausibly fast cycle is rejected',()=>{
  const w=new PoseWorkout(); w.setExercise('squat'); hold(w,pose('squat'),0);
  hold(w,pose('squat',true),700,200);
  assert.equal(hold(w,pose('squat'),1000,200).reps,0);
});
test('squat lean and jack coordination errors mark completed reps incorrect',()=>{
  const squat=new PoseWorkout(); squat.setExercise('squat');
  const bad=pose('squat',true); bad[11].x+=0.3; bad[12].x+=0.3;
  hold(squat,pose('squat'),0); hold(squat,bad,700);
  assert.equal(hold(squat,pose('squat'),1400).incorrectReps,1);
  assert.equal(squat.summary().feedbackCounts.squat_torso_lean,1);
  const jack=new PoseWorkout(); jack.setExercise('jumpingJack');
  hold(jack,pose('jumpingJack'),0); hold(jack,pose('jumpingJack',true,true),700,300);
  hold(jack,pose('jumpingJack',true),1100,300);
  assert.equal(hold(jack,pose('jumpingJack'),1500).incorrectReps,1);
  assert.equal(jack.summary().feedbackCounts.jack_coordination,1);
});
