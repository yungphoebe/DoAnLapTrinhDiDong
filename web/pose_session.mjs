// A monotonic clock excludes pauses/background time; freeze the payload for retries.
export class PoseSession {
  constructor(id, startedAt) {
    this.id = id;
    this.startedAt = startedAt;
    this.activeSince = null;
    this.elapsed = 0;
    this.payload = null;
  }
  resume(now) {
    if (!this.payload && this.activeSince === null) this.activeSince = now;
  }
  pause(now) {
    if (this.activeSince === null) return;
    this.elapsed += Math.max(0, now - this.activeSince);
    this.activeSince = null;
  }
  seconds(now) {
    return Math.floor((this.elapsed + (this.activeSince === null ? 0 : Math.max(0, now - this.activeSince))) / 1000);
  }
  finish(now, summary) {
    if (!this.payload) {
      this.pause(now);
      this.payload = {id:this.id, startedAt:this.startedAt, durationSeconds:this.seconds(now), ...structuredClone(summary)};
    }
    return this.payload;
  }
}
