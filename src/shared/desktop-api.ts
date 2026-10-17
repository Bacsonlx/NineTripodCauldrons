export interface DesktopApi {
  getAppVersion(): Promise<string>;
  toggleFullscreen(): Promise<void>;
  getWindowState(): Promise<{ fullscreen: boolean }>;
  onWindowStateChange(listener: (state: { fullscreen: boolean }) => void): () => void;
}

export const APP_VERSION_CHANNEL = 'app:get-version';
export const FULLSCREEN_CHANNEL = 'window:toggle-fullscreen';
export const WINDOW_STATE_CHANNEL = 'window:state';
