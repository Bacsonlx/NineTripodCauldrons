module.exports = {
  packagerConfig: {
    asar: true,
    executableName: 'nine-tripod-cauldrons',
    appBundleId: 'com.bacsonlx.ninetripodcauldrons',
  },
  makers: [
    { name: '@electron-forge/maker-zip', platforms: ['darwin', 'win32'] },
  ],
  plugins: [
    {
      name: '@electron-forge/plugin-webpack',
      config: {
        mainConfig: './webpack.main.config.cjs',
        devContentSecurityPolicy:
          "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; connect-src 'self' ws://localhost:*; object-src 'none'; base-uri 'none'",
        renderer: {
          config: './webpack.renderer.config.cjs',
          entryPoints: [
            {
              html: './src/renderer/index.html',
              js: './src/renderer/index.ts',
              name: 'main_window',
              preload: { js: './src/desktop/preload.ts' },
            },
          ],
        },
      },
    },
  ],
};
