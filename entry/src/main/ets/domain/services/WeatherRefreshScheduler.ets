export class WeatherRefreshScheduler {
  private timerId: number = -1;

  public start(intervalMs: number, callback: () => void): void {
    this.stop();
    if (!Number.isFinite(intervalMs) || intervalMs <= 0) {
      return;
    }
    this.timerId = setInterval(() => {
      callback();
    }, intervalMs);
  }

  public stop(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  public isRunning(): boolean {
    return this.timerId !== -1;
  }
}

