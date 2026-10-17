import { app, BrowserWindow, ipcMain, Menu } from 'electron';
import { APP_VERSION_CHANNEL, FULLSCREEN_CHANNEL, WINDOW_STATE_CHANNEL } from '../shared/desktop-api';

declare const MAIN_WINDOW_WEBPACK_ENTRY: string;
declare const MAIN_WINDOW_PRELOAD_WEBPACK_ENTRY: string;

function createWindow(): void {
  const window = new BrowserWindow({
    width: 1280,
    height: 720,
    minWidth: 800,
    minHeight: 450,
    useContentSize: true,
    show: false,
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
  const notifyState = () => window.webContents.send(WINDOW_STATE_CHANNEL, { fullscreen: window.isFullScreen() });
  window.on('enter-full-screen', notifyState);
  window.on('leave-full-screen', notifyState);
  window.once('ready-to-show', () => { window.maximize(); window.show(); });
  void window.loadURL(MAIN_WINDOW_WEBPACK_ENTRY);
}

void app.whenReady().then(() => {
  ipcMain.handle(APP_VERSION_CHANNEL, () => app.getVersion());
  ipcMain.handle(FULLSCREEN_CHANNEL, event => {
    const window = BrowserWindow.fromWebContents(event.sender);
    if (window) window.setFullScreen(!window.isFullScreen());
  });
  ipcMain.handle(WINDOW_STATE_CHANNEL, event => ({ fullscreen: BrowserWindow.fromWebContents(event.sender)?.isFullScreen() ?? false }));
  Menu.setApplicationMenu(Menu.buildFromTemplate([
    ...(process.platform === 'darwin' ? [{ role: 'appMenu' as const }] : []),
    { label: '窗口', submenu: [{ role: 'togglefullscreen', label: '切换全屏' }] },
  ]));
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
