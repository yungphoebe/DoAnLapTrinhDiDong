const exercises = ['squat', 'pushup', 'jumpingJack', 'shoulderPress', 'bicepsCurl'];
const messages = {
  tracking: 'Đưa toàn thân vào khung hình, bảo đảm thấy rõ các khớp.',
  identifying: 'Squat/chống đẩy: quay ngang. Jumping Jack: quay chính diện.',
  squat_torso_lean: 'Giữ thân trên ổn định, giảm nghiêng người về trước.',
  pushup_body_line: 'Giữ vai, hông và cổ chân thành một đường thẳng.',
  jack_coordination: 'Phối hợp mở chân và đưa hai tay lên cùng nhau.',
  shoulder_press_lock: 'Giữ thân người ổn định khi đẩy tay lên.',
  shoulder_press_asymmetry: 'Đưa hai tay lên xuống cùng nhịp.',
  biceps_swing: 'Giữ khuỷu tay sát thân, không đung đưa người.',
};
const distance = (a,b) => Math.hypot(a.x-b.x,a.y-b.y);
function angle(a,b,c) {
  const ab=distance(a,b), cb=distance(c,b);
  if(ab<0.015 || cb<0.015) return null;
  return Math.acos(Math.max(-1,Math.min(1,((a.x-b.x)*(c.x-b.x)+(a.y-b.y)*(c.y-b.y))/(ab*cb))))*180/Math.PI;
}

// Image-space heuristics, not a clinical assessment: side-on squat/pushup,
// frontal jack. Squat/pushup use one visible side; jack requires both sides.
// 0.6 visibility, 200 ms classification / 150 ms phase dwell,
// >=700 ms full cycles. Missing joints or >1 s frame gaps discard partial reps.
// update returns SESSION totals; summary returns per-exercise totals.
export class PoseWorkout {
  constructor() {
    this.mode='auto'; this.counts={}; this.feedbackCounts={}; this.resetMotion();
  }
  resetMotion() {
    this.exercise=null; this.candidate=null; this.candidateSince=0;
    this.phase='waiting'; this.zone=null; this.zoneSince=0; this.cycleStart=null;
    this.bad=false; this.previousCodes=new Set(); this.lastTime=null; this.side=null;
  }
  setExercise(mode) {
    if(mode!=='auto' && !exercises.includes(mode)) throw new Error('Unknown exercise');
    if(mode!==this.mode) { this.mode=mode; this.resetMotion(); }
  }
  summary() {
    return {exercises:Object.entries(this.counts).map(([exercise,v])=>({exercise,...v})),feedbackCounts:{...this.feedbackCounts}};
  }
  result(tracking, codes, value=null) {
    const totals=Object.values(this.counts).reduce((a,v)=>({reps:a.reps+v.reps,correctReps:a.correctReps+v.correctReps,incorrectReps:a.incorrectReps+v.incorrectReps}),{reps:0,correctReps:0,incorrectReps:0});
    return {exercise:this.exercise,feedback:codes.map(c=>messages[c]),feedbackCodes:codes,tracking,phase:this.phase,angle:value,...totals};
  }
  update(landmarks, timestampMs, width=1, height=1) {
    if(!Number.isFinite(timestampMs) || !Number.isFinite(width) || !Number.isFinite(height) || width<=0 || height<=0 ||
      !Array.isArray(landmarks)) {
      this.resetMotion(); return this.result(false,['tracking']);
    }
    if(this.lastTime!==null && (timestampMs<=this.lastTime || timestampMs-this.lastTime>1000)) this.resetMotion();
    const shoulderMode = this.mode==='shoulderPress';
    const upperBody = shoulderMode || this.mode==='bicepsCurl';
    const visibilityThreshold = upperBody ? 0.0 : 0.6;
    const visible=i=>{const point=landmarks[i]; return point && Number.isFinite(point.x) && Number.isFinite(point.y) && point.x>=0 && point.x<=1 && point.y>=0 && point.y<=1 && (!Number.isFinite(point.visibility) || point.visibility>=visibilityThreshold);};
    const p=landmarks.map(v=>({...v,x:v?.x*width/height}));
    if (shoulderMode) {
      const shoulderPoints = [11, 12].filter(visible).map(i => p[i]);
      const wristPoints = [15, 16].filter(visible).map(i => p[i]);
      if (shoulderPoints.length === 0 || wristPoints.length === 0) {
        this.resetMotion();
        return this.result(false, ['tracking']);
      }
      const shoulderY = shoulderPoints.reduce((sum, point) => sum + point.y, 0) / shoulderPoints.length;
      const wristY = wristPoints.reduce((sum, point) => sum + point.y, 0) / wristPoints.length;
      const shoulderWidth = shoulderPoints.length > 1
        ? Math.abs(p[11].x - p[12].x)
        : 0.1;
      const armsUp = wristY < shoulderY - Math.max(0.03, shoulderWidth * 0.2);
      const armsDown = wristY > shoulderY + Math.max(0.03, shoulderWidth * 0.2);
      const zone = armsUp ? 'active' : armsDown ? 'baseline' : null;
      const codes = wristPoints.length < 2 ? ['shoulder_press_asymmetry'] : [];
      for (const code of codes) {
        if (!this.previousCodes.has(code)) {
          this.feedbackCounts[code] = (this.feedbackCounts[code] ?? 0) + 1;
        }
      }
      this.previousCodes = new Set(codes);
      if (this.phase !== 'waiting' && codes.length) this.bad = true;
      if (zone !== this.zone) {
        this.zone = zone;
        this.zoneSince = timestampMs;
        if (this.phase === 'ready' && zone === 'active' && this.cycleStart === null) {
          this.cycleStart = timestampMs;
        }
      }
      if (zone && timestampMs - this.zoneSince >= 100) {
        if (zone === 'baseline') {
          if (this.phase === 'active' && this.cycleStart !== null &&
              timestampMs - this.cycleStart >= 100) {
            const row = this.counts[this.mode] ??= {
              reps: 0,
              correctReps: 0,
              incorrectReps: 0,
            };
            row.reps++;
            row[this.bad ? 'incorrectReps' : 'correctReps']++;
          }
          this.phase = 'ready';
          this.cycleStart = null;
          this.bad = false;
        } else if (zone === 'active' && this.phase !== 'active') {
          this.phase = 'active';
          this.cycleStart ??= timestampMs;
        }
      }
      this.lastTime = timestampMs;
      return this.result(true, codes);
    }
    const sides=[0,1].map(side=>{
      const required=shoulderMode
        ? [11,15].map(i=>i+side)
        : upperBody
          ? [11,13,15].map(i=>i+side)
        : [11,23,25,27].map(i=>i+side);
      if(!required.every(visible)) return null;
      const shoulder=p[11+side], hip=p[23+side], ankle=p[27+side];
      const horizontal=upperBody
        ? false
        : Math.abs(shoulder.x-ankle.x)>Math.abs(shoulder.y-ankle.y)*1.5;
      const needArms=['pushup','bicepsCurl'].includes(this.mode) ||
        (this.mode==='auto' && horizontal);
      if(needArms) required.push(13+side,15+side);
      if(!required.every(visible)) return null;
      const knee=upperBody ? null : angle(hip,p[25+side],ankle);
      const body=upperBody ? null : angle(shoulder,hip,ankle);
      const elbow=needArms ? angle(shoulder,p[13+side],p[15+side]) : null;
      if((!upperBody && (knee===null || body===null)) || (needArms && elbow===null)) return null;
      return {side,shoulder,hip,ankle,horizontal,knee,body,elbow,score:Math.min(...required.map(i=>landmarks[i].visibility))};
    }).filter(Boolean).sort((a,b)=>b.score-a.score);
    // Keep a usable side through a cycle so confidence flicker cannot splice two limbs.
    const selected=sides.find(s=>s.side===this.side)??sides[0];
    if(!selected) {this.resetMotion(); return this.result(false,['tracking']);}
    if(this.side!==null && selected.side!==this.side) this.resetMotion();
    this.side=selected.side;
    this.lastTime=timestampMs;
    const {shoulder,hip,ankle,knee,elbow,body,horizontal}=selected;
    const torso=upperBody ? distance(p[11],p[12]) : distance(shoulder,hip);
    const upright=upperBody || (shoulder.y<hip.y && hip.y<ankle.y);
    const frontal=visible(11) && visible(12) &&
      Math.abs(p[11].x-p[12].x)>torso*0.45;
    const candidate=this.mode==='auto' ? (horizontal?'pushup':upright?(frontal?'jumpingJack':'squat'):null) : this.mode;
    if(candidate==='jumpingJack' && ![11,12,15,16,23,24,25,26,27,28].every(visible)) {
      this.resetMotion(); return this.result(false,['tracking']);
    }
    if(candidate!==this.candidate) { this.candidate=candidate; this.candidateSince=timestampMs; }
    if(candidate!==this.exercise) {
      this.phase='waiting'; this.zone=null; this.cycleStart=null; this.bad=false;
      if(candidate && (this.mode!=='auto' || timestampMs-this.candidateSince>=200)) this.exercise=candidate;
      else { this.exercise=null; return this.result(true,['identifying']); }
    }
    if(!this.exercise) return this.result(true,['identifying']);
    let zone=null, value=null; const codes=[];
    if(this.exercise==='squat') {
      if(!upright || horizontal) {this.resetMotion(); return this.result(false,['tracking']);}
      value=knee; zone=knee>160?'baseline':knee<110?'active':null;
      if(Math.abs(shoulder.x-hip.x)>Math.abs(shoulder.y-hip.y)*0.8) codes.push('squat_torso_lean');
    } else if(this.exercise==='pushup') {
      if(!horizontal) {this.resetMotion(); return this.result(false,['tracking']);}
      value=elbow; zone=elbow>155?'baseline':elbow<105?'active':null;
      if(body<155) codes.push('pushup_body_line');
    } else if(this.exercise==='shoulderPress') {
      if(!upright || !frontal) {this.resetMotion(); return this.result(false,['tracking']);}
      if (![11,12,15,16].every(visible)) {
        this.resetMotion(); return this.result(false,['tracking']);
      }
      const leftUp=p[15].y<p[11].y, rightUp=p[16].y<p[12].y;
      const leftDown=p[15].y>p[11].y, rightDown=p[16].y>p[12].y;
      const armsUp=leftUp || rightUp;
      const armsDown=leftDown || rightDown;
      zone=armsUp?'active':armsDown?'baseline':null;
      if (leftUp !== rightUp || leftDown !== rightDown) {
        codes.push('shoulder_press_asymmetry');
      }
      if(Math.abs(p[11].y-p[12].y)>torso*0.8) codes.push('shoulder_press_lock');
    } else if(this.exercise==='bicepsCurl') {
      if(!visible(11) || !visible(13) || !visible(15)) {
        this.resetMotion(); return this.result(false,['tracking']);
      }
      value=elbow; zone=elbow>145?'baseline':elbow<105?'active':null;
      if(Math.abs(shoulder.x-p[13].x)>Math.abs(shoulder.y-p[13].y)*0.8) codes.push('biceps_swing');
    } else {
      if(!upright || !frontal) {this.resetMotion(); return this.result(false,['tracking']);}
      const armsUp=p[15].y<p[11].y && p[16].y<p[12].y;
      const armsDown=p[15].y>p[11].y+torso*0.5 && p[16].y>p[12].y+torso*0.5;
      const spread=Math.abs(p[27].x-p[28].x)/Math.max(0.01,Math.abs(p[11].x-p[12].x));
      zone=armsDown && spread<1.3?'baseline':armsUp && spread>1.8?'active':null;
      if((armsDown && spread>1.8) || (armsUp && spread<1.3)) codes.push('jack_coordination');
    }
    for(const code of codes) if(!this.previousCodes.has(code)) this.feedbackCounts[code]=(this.feedbackCounts[code]??0)+1;
    this.previousCodes=new Set(codes);
    if(this.phase!=='waiting' && codes.length) this.bad=true;
    if(zone!==this.zone) {
      this.zone=zone; this.zoneSince=timestampMs;
      if(this.phase==='ready' && zone!=='baseline' && this.cycleStart===null) this.cycleStart=timestampMs;
    }
    if(zone && timestampMs-this.zoneSince>=150) {
      if(zone==='baseline') {
        if(this.phase==='active' && timestampMs-this.cycleStart>=300) {
          const row=this.counts[this.exercise]??={reps:0,correctReps:0,incorrectReps:0};
          row.reps++; row[this.bad?'incorrectReps':'correctReps']++;
        }
        this.phase='ready'; this.cycleStart=null; this.bad=false;
      } else if(this.phase==='ready') this.phase='active';
    }
    return this.result(true,codes,value);
  }
}
