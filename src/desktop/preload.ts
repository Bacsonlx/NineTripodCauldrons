import { contextBridge, ipcRenderer } from 'electron';
import { APP_VERSION_CHANNEL, type DesktopApi } from '../shared/desktop-api';

const desktop: DesktopApi = {
  getAppVersion: () => ipcRenderer.invoke(APP_VERSION_CHANNEL),
};

contextBridge.exposeInMainWorld('desktop', desktop);
