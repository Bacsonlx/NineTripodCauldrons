export interface DesktopApi {
  getAppVersion(): Promise<string>;
}

export const APP_VERSION_CHANNEL = 'app:get-version';
