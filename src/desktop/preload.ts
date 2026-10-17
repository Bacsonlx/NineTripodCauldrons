import { contextBridge, ipcRenderer } from 'electron';
import { APP_VERSION_CHANNEL, FULLSCREEN_CHANNEL, WINDOW_STATE_CHANNEL, type DesktopApi } from '../shared/desktop-api';

const desktop: DesktopApi = {
  getAppVersion: () => ipcRenderer.invoke(APP_VERSION_CHANNEL),
  toggleFullscreen: () => ipcRenderer.invoke(FULLSCREEN_CHANNEL),
  getWindowState: () => ipcRenderer.invoke(WINDOW_STATE_CHANNEL),
  onWindowStateChange: listener => {
    const handler = (_event: Electron.IpcRendererEvent, state: { fullscreen: boolean }) => listener(state);
    ipcRenderer.on(WINDOW_STATE_CHANNEL, handler);
    return () => ipcRenderer.removeListener(WINDOW_STATE_CHANNEL, handler);
  },
};

contextBridge.exposeInMainWorld('desktop', desktop);
