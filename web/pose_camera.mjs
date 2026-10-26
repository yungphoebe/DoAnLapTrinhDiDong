import { PoseWorkout } from './pose_rules.mjs';
import { PoseSession } from './pose_session.mjs';
import { PoseVoice } from './pose_voice.mjs';

const $ = id => document.getElementById(id);
const video = $('video'), canvas = $('skeleton'), context = canvas.getContext('2d');
const engine = new PoseWorkout();
const voice = new PoseVoice({ onError: message => { $('voice-note').textContent = message; } });
const names = {squat:'Squat',pushup:'Chống đẩy',jumpingJack:'Jumping Jack',shoulderPress:'Đẩy vai',bicepsCurl:'Tập tay trước'};
const edges = [[11,12],[11,13],[13,15],[12,14],[14,16],[11,23],[12,24],[23,24],[23,25],[25,27],[24,26],[26,28],[27,29],[29,31],[28,30],[30,32]];
let stream, worker, session, pending, saveTimer, animation, lastFrame = -1, lastTimestamp = 0;
let busy = false, ready = false, running = false, opening = false, disposed = false, saved = false;
let generation = 0, previousReps = 0;
let cancelInitialization;

window.addEventListener('message', event => {
  if (event.origin !== location.origin || event.source !== window.parent) return;
  let message;
  try { message = JSON.parse(event.data); } catch (_) { return; }
  if (message.type !== 'aigym:configure') return;
  const exercise = message.exercise;
  if (!['squat', 'pushup', 'jumpingJack', 'shoulderPress', 'bicepsCurl'].includes(exercise)) return;
  $('exercise').value = exercise;
  $('exercise').disabled = true;
  status(`Bài đang chọn: ${names[exercise]}. Bấm Mở camera để bắt đầu.`);
});

function status(text) { $('status').textContent = text; }
function clearOverlay() { context.clearRect(0,0,canvas.width,canvas.height); }
function controls() {
  $('start').disabled = opening || disposed || !!pending || running;
  $('start').textContent = opening ? 'Đang mở...' : ready ? 'Bắt đầu / Tiếp tục' : 'Mở camera';
  $('pause').disabled = !running;
  $('finish').disabled = !session || !!pending || opening;
  $('exercise').disabled = !!pending;
}
function speak(text, force = false) {
  voice.enabled = $('voice').checked;
  voice.speak(text, force);
}
function voiceSupport() {
  if (!voice.supported) {
    $('voice').disabled=true; $('voice').checked=false; $('voice-test').disabled=true;
    $('voice-note').textContent='Trình duyệt không hỗ trợ giọng nói. Hãy mở ứng dụng bằng Chrome.'; return;
  }
  $('voice-note').textContent = voice.hasVietnameseVoice
    ? 'Đã có giọng Việt. Camera sẽ đọc hướng dẫn và số lần tập; nhắc tư thế tối đa một lần mỗi 5 giây.'
    : 'Đang dùng ngôn ngữ vi-VN của trình duyệt. Nếu không nghe tiếng Việt, hãy thêm giọng tiếng Việt trong cài đặt giọng nói của máy rồi mở lại Chrome.';
}
voiceSupport();
if ('speechSynthesis' in window) speechSynthesis.addEventListener('voiceschanged',voiceSupport);
$('voice').onchange = () => {
  voice.enabled = $('voice').checked;
  if (voice.enabled) speak('Đã bật hướng dẫn tiếng Việt. Hãy đặt toàn thân trong khung hình.',true);
};
$('voice-test').onclick = () => {
  $('voice').checked = true;
  voiceSupport();
  speak('Xin chào! Tôi sẽ hướng dẫn bạn tập luyện bằng tiếng Việt. Hãy giữ lưng thẳng và thực hiện động tác chậm rãi.',true);
};

function pause() {
  running=false; session?.pause(performance.now()); engine.resetMotion();
  clearOverlay(); voice.stop(); controls();
}
function releaseCamera() {
  pause(); generation++; ready=false; busy=false;
  cancelInitialization?.(); cancelInitialization=null; opening=false;
  cancelAnimationFrame(animation);
  stream?.getTracks().forEach(track=>track.stop()); stream=null; video.srcObject=null;
  worker?.terminate(); worker=null;
  $('badge').textContent='Camera đã dừng'; controls();
}
function dispose() {
  disposed=true; releaseCamera(); clearTimeout(saveTimer);
  voice.dispose();
  clearInterval(clockTimer);
  if ('speechSynthesis' in window) speechSynthesis.removeEventListener('voiceschanged',voiceSupport);
}
function draw(landmarks, width, height, state) {
  if (canvas.width !== width || canvas.height !== height) { canvas.width=width;canvas.height=height; }
  clearOverlay();
  const visible = p => p && p.visibility >= .25 && p.x>=0 && p.x<=1 && p.y>=0 && p.y<=1;
  const color=state==='bad' ? '#ff3b30' : state==='good' ? '#35e06f' : '#b779ff';
  context.strokeStyle=color; context.fillStyle=color; context.lineWidth=3;
  for (const [a,b] of edges) {
    if (!visible(landmarks[a]) || !visible(landmarks[b])) continue;
    context.beginPath();context.moveTo(landmarks[a].x*width,landmarks[a].y*height);
    context.lineTo(landmarks[b].x*width,landmarks[b].y*height); context.stroke();
  }
  for (const p of landmarks) if (visible(p)) {
    context.beginPath();context.arc(p.x*width,p.y*height,4,0,Math.PI*2);context.fill();
  }
}
async function frame(now) {
  if (disposed || !ready) return;
  animation=requestAnimationFrame(frame);
  if (!running || busy || now-lastTimestamp<80 || video.readyState<2 || video.currentTime===lastFrame) return;
  busy=true; lastTimestamp=now;lastFrame=video.currentTime;
  const version=generation;
  try {
    const bitmap=await createImageBitmap(video);
    if (version!==generation || !running || !worker) {bitmap.close();busy=false;return;}
    worker.postMessage({type:'frame',frame:bitmap,timestamp:now},[bitmap]);
  } catch (_) { busy=false; pause();status('Không đọc được camera. Bấm tiếp tục để thử lại.'); }
}
async function open() {
  if (opening || disposed || pending) return;
  if (ready) { resume();return; }
  opening=true;controls();status('Đang mở camera và tải mô hình trên máy…');
  speak('Đang mở camera. Hãy cho phép truy cập camera khi trình duyệt yêu cầu.',true);
  const version=++generation;
  try {
    if (!navigator.mediaDevices?.getUserMedia) throw new Error('Camera cần localhost hoặc HTTPS.');
    const next=await navigator.mediaDevices.getUserMedia({video:{width:{ideal:640},height:{ideal:480},facingMode:'user'},audio:false});
    if (disposed || version!==generation) {next.getTracks().forEach(t=>t.stop());return;}
    stream=next;video.srcObject=stream;await video.play();
    if (disposed || version!==generation) return;
    for(const track of stream.getVideoTracks()) track.onended=()=>{releaseCamera();status('Camera bị ngắt. Bấm Mở camera để kết nối lại.');};
    $('video').parentElement.style.aspectRatio=`${video.videoWidth}/${video.videoHeight}`;
    worker=new Worker(new URL('./pose_worker.mjs',import.meta.url));
    await new Promise((resolve,reject)=>{
      const timeout=setTimeout(()=>reject(new Error('Tải mô hình quá lâu. Hãy thử lại.')),45000);
      cancelInitialization=()=>{clearTimeout(timeout);reject(new Error('Đã dừng khởi tạo camera.'));};
      worker.onerror=()=>{clearTimeout(timeout);reject(new Error('Không tải được bộ nhận diện.'));};
      worker.onmessage=({data})=>{
        if(data.type==='ready'){clearTimeout(timeout);cancelInitialization=null;resolve();}
        else if(data.type==='error'){clearTimeout(timeout);reject(new Error(data.message));}
      };
      worker.postMessage({type:'init'});
    });
    if (disposed || version!==generation) return;
    worker.onerror=()=>{releaseCamera();status('Bộ nhận diện đã dừng. Bấm Mở camera để thử lại.');};
    worker.onmessage=({data})=>{
      if(version!==generation) return;
      busy=false;
      if(data.type==='error'){releaseCamera();status('Không phân tích được khung hình. Hãy mở lại camera.');return;}
      if(data.type!=='pose'||!running)return;
      const result=engine.update(data.landmarks,data.timestamp,data.width,data.height);
      const state=!result.tracking ? 'neutral' : result.feedbackCodes.length ? 'bad' : 'good';
      draw(data.landmarks,data.width,data.height,state);
      $('badge').textContent=result.exercise ? names[result.exercise] : 'Đang nhận diện bài';
      $('badge').className=`badge ${state}`;
      $('reps').textContent=result.reps; $('correct').textContent=result.correctReps; $('incorrect').textContent=result.incorrectReps;
      $('live-reps').textContent=result.reps;
      $('live-correct').textContent=result.correctReps;
      $('live-incorrect').textContent=result.incorrectReps;
      const feedback=result.feedback.join(' ') || (result.tracking
        ? 'Tiếp tục động tác đủ biên độ.'
        : $('exercise').value === 'shoulderPress'
          ? 'Lùi camera để thấy vai và ít nhất một cổ tay.'
          : 'Đặt toàn thân trong khung hình.');
      $('feedback').textContent=feedback;
      $('feedback').className=state;
      if(result.feedbackCodes.length || !result.tracking) speak(feedback);
      else if(result.reps>previousReps) speak(`${result.reps} lần.`,false);
      previousReps=result.reps;
    };
    ready=true; lastFrame=-1; resume();animation=requestAnimationFrame(frame);
  } catch(error) {
    if(!disposed && version===generation) {
      releaseCamera(); status(error.name==='NotAllowedError' ? 'Chưa được cấp quyền camera. Cho phép camera rồi thử lại.' : `Không mở được camera: ${error.message}`);
      speak($('status').textContent,true);
    }
  } finally {if(version===generation) opening=false;controls();}
}
function resume() {
  if(!ready || pending || disposed)return;
  session ??= new PoseSession(crypto.randomUUID(),new Date().toISOString());
  engine.resetMotion();running=true;session.resume(performance.now());
  status('Đang theo dõi chuyển động.');controls();
  speak('Bắt đầu tập luyện. Hãy đặt toàn thân trong khung hình và thực hiện động tác chậm rãi.',true);
}
function sendSave() {
  if(!pending || saved)return;
  if(window.parent===window){$('save-status').textContent='Mở camera từ ứng dụng và đăng nhập để lưu.';return;}
  $('retry').hidden=true;$('save-status').textContent='Đang lưu vào tài khoản…';
  window.parent.postMessage(JSON.stringify({type:'aigym:save',requestId:pending.id,session:pending}),location.origin);
  clearTimeout(saveTimer);
  saveTimer=setTimeout(()=>{$('save-status').textContent='Chưa nhận được xác nhận. Thử lưu lại để kiểm tra.';$('retry').hidden=false;},15000);
}
function finish() {
  if(!session || pending)return;
  pause();pending=session.finish(performance.now(),engine.summary());releaseCamera();
  $('result').hidden=false;
  $('summary').textContent=`${pending.durationSeconds} giây hoạt động\n`+pending.exercises.map(x=>`${names[x.exercise]}: ${x.reps} reps · ${x.correctReps} đạt · ${x.incorrectReps} có lỗi`).join('\n');
  if(pending.durationSeconds<1){$('save-status').textContent='Phiên dưới 1 giây, không lưu.';saved=true;}
  else sendSave();
  const totals = pending.exercises.reduce((sum, exercise) => ({
    reps: sum.reps + exercise.reps,
    correct: sum.correct + exercise.correctReps,
  }), {reps:0,correct:0});
  speak(`Đã kết thúc phiên tập. Bạn hoàn thành ${totals.reps} lần, trong đó ${totals.correct} lần đạt tư thế.`,true);
  controls();
}
window.addEventListener('message',event=>{
  if(event.origin!==location.origin||event.source!==window.parent||typeof event.data!=='string')return;
  let data;try{data=JSON.parse(event.data);}catch{return;}
  if(data.type==='aigym:dispose'){dispose();return;}
  if(data.type!=='aigym:saved'||!pending||data.requestId!==pending.id)return;
  clearTimeout(saveTimer);saved=data.ok===true;
  $('save-status').textContent=saved?'Đã lưu lịch sử vào tài khoản.':(data.message||'Chưa lưu được phiên tập.');
  $('retry').hidden=saved;
});
$('start').onclick=open;
$('pause').onclick=()=>{pause();status('Đã tạm dừng. Bấm tiếp tục để tập.');speak('Đã tạm dừng. Bấm tiếp tục khi bạn sẵn sàng.',true);};
$('finish').onclick=finish;$('retry').onclick=sendSave;
$('exercise').onchange=()=>{engine.setExercise($('exercise').value);clearOverlay();};
$('close').onclick=()=>{
  if(session&&!saved&&session.seconds(performance.now())>0&&!confirm('Phiên tập chưa lưu. Đóng và bỏ phiên này?'))return;
  dispose();window.parent.postMessage(JSON.stringify({type:'aigym:close'}),location.origin);
};
document.addEventListener('visibilitychange',()=>{if(document.hidden){releaseCamera();status('Đã tạm dừng khi chuyển trang. Bấm Mở camera để tiếp tục.');}});
window.addEventListener('pagehide',dispose);
const clockTimer=setInterval(()=>{const seconds=session?.seconds(performance.now())??0;$('time').textContent=`${String(Math.floor(seconds/60)).padStart(2,'0')}:${String(seconds%60).padStart(2,'0')}`;},250);
controls();
