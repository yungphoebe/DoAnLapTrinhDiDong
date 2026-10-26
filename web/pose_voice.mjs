// Browser speech only: the app never sends camera frames to a speech service.
export class PoseVoice {
  constructor({ synth = globalThis.speechSynthesis,
    Utterance = globalThis.SpeechSynthesisUtterance,
    now = () => performance.now(), onError = () => {} } = {}) {
    this.synth = synth;
    this.Utterance = Utterance;
    this.now = now;
    this.onError = onError;
    this._enabled = true;
    this.disposed = false;
    this.spokenAt = -Infinity;
    this.lastText = '';
  }

  get supported() { return !!this.synth && typeof this.Utterance === 'function'; }
  get enabled() { return this._enabled; }
  set enabled(value) { this._enabled = !!value; if (!this._enabled) this.stop(); }
  get vietnameseVoice() {
    const voices = this.synth?.getVoices() ?? [];
    return voices.find(v => v.lang.toLowerCase() === 'vi-vn')
      ?? voices.find(v => v.lang.toLowerCase().startsWith('vi'));
  }
  get hasVietnameseVoice() { return !!this.vietnameseVoice; }

  speak(text, force = false) {
    if (!this.supported || !this.enabled || this.disposed || !text?.trim()) return false;
    const now = this.now();
    if (!force && (this.synth.speaking || now - this.spokenAt < 5000
      || (text === this.lastText && now - this.spokenAt < 15000))) return false;
    try {
      this.stop();
      const message = new this.Utterance(text);
      message.lang = 'vi-VN';
      message.rate = .95;
      message.volume = 1;
      const voice = this.vietnameseVoice;
      if (voice) message.voice = voice;
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

  stop() { this.synth?.cancel(); }
  dispose() { this.disposed = true; this.stop(); }
}
