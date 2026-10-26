import { vietnameseClips } from './pose_voice_clips.mjs';

// Browser speech with bundled Vietnamese audio; no camera data leaves the device for speech.
export class PoseVoice {
  constructor({ synth = globalThis.speechSynthesis,
    Utterance = globalThis.SpeechSynthesisUtterance,
    Audio = globalThis.Audio, now = () => performance.now(), onError = () => {} } = {}) {
    this.synth = synth;
    this.Utterance = Utterance;
    this.Audio = Audio;
    this.now = now;
    this.onError = onError;
    this._enabled = true;
    this.disposed = false;
    this.spokenAt = -Infinity;
    this.lastText = '';
    this.audio = null;
    this.playback = 0;
  }

  get supported() { return (!!this.synth && typeof this.Utterance === 'function') || typeof this.Audio === 'function'; }
  get enabled() { return this._enabled; }
  set enabled(value) { this._enabled = !!value; if (!this._enabled) this.stop(); }
  get vietnameseVoice() {
    const voices = this.synth?.getVoices() ?? [];
    const locale = v => v.lang.toLowerCase().replaceAll('_', '-');
    return voices.find(v => locale(v) === 'vi-vn')
      ?? voices.find(v => locale(v) === 'vi' || locale(v).startsWith('vi-'));
  }
  get hasVietnameseVoice() { return !!this.vietnameseVoice; }

  speak(text, force = false) {
    if (!this.supported || !this.enabled || this.disposed || !text?.trim()) return false;
    const now = this.now();
    if (!force && (this.synth?.speaking || this.audio || now - this.spokenAt < 5000
      || (text === this.lastText && now - this.spokenAt < 15000))) return false;
    try {
      this.stop();
      const voice = this.vietnameseVoice;
      if (!voice || !this.synth || typeof this.Utterance !== 'function') {
        const clips = vietnameseClips(text);
        if (!clips || typeof this.Audio !== 'function') {
          this.onError('Chưa có giọng tiếng Việt cho hướng dẫn này. Không sử dụng giọng tiếng Anh thay thế.');
          return false;
        }
        this.playClips(clips, this.playback);
        this.spokenAt = now;
        this.lastText = text;
        return true;
      }
      const message = new this.Utterance(text);
      message.lang = 'vi-VN';
      message.rate = .95;
      message.volume = 1;
      message.voice = voice;
      message.onerror = event => {
        if (!this.disposed && this.enabled && !['canceled', 'interrupted'].includes(event.error)) {
          this.onError('Không phát được giọng Việt. Kiểm tra âm lượng, quyền âm thanh và giọng tiếng Việt trên máy, rồi bấm Nghe thử.');
        }
      };
      this.synth.resume();
      this.synth.speak(message);
      this.spokenAt = now;
      this.lastText = text;
      return true;
    } catch (_) {
      this.onError('Không phát được giọng nói. Hãy thử lại bằng Chrome và kiểm tra quyền âm thanh.');
      return false;
    }
  }

  playClips(clips, version) {
    if (this.disposed || !this.enabled || version !== this.playback || !clips.length) return;
    const audio = new this.Audio(new URL(`pose-audio/vi/${clips[0]}.mp3`, import.meta.url).href);
    this.audio = audio;
    const failed = () => {
      if (version !== this.playback || this.disposed || !this.enabled) return;
      this.stop();
      this.onError('Không phát được âm thanh tiếng Việt. Kiểm tra âm lượng và quyền âm thanh, rồi bấm Nghe thử.');
    };
    audio.onended = () => {
      if (version !== this.playback) return;
      this.audio = null;
      this.playClips(clips.slice(1), version);
    };
    audio.onerror = failed;
    try { audio.play()?.catch(failed); } catch (_) { failed(); }
  }

  stop() {
    this.playback++;
    this.synth?.cancel();
    if (this.audio) {
      this.audio.onended = null;
      this.audio.onerror = null;
      this.audio.pause();
      this.audio = null;
    }
  }
  dispose() { this.disposed = true; this.stop(); }
}
