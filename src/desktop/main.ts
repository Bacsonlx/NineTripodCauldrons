import { app, BrowserWindow, ipcMain } from 'electron';
import { APP_VERSION_CHANNEL } from '../shared/desktop-api';

declare const MAIN_WINDOW_WEBPACK_ENTRY: string;
declare const MAIN_WINDOW_PRELOAD_WEBPACK_ENTRY: string;

function createWindow(): void {
  const window = new BrowserWindow({
    width: 1280,
    height: 720,
    minWidth: 800,
    minHeight: 450,
    useContentSize: true,
    title: '九鼎 · 十日',
    backgroundColor: '#171b1b',
    webPreferences: {
      preload: MAIN_WINDOW_PRELOAD_WEBPACK_ENTRY,
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });

  window.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
  void window.loadURL(MAIN_WINDOW_WEBPACK_ENTRY);
}

void app.whenReady().then(() => {
  ipcMain.handle(APP_VERSION_CHANNEL, () => app.getVersion());
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
