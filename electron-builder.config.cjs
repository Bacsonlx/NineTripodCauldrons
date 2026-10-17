// Forge owns compilation and app packaging; builder only wraps its Windows output.
module.exports = {
  appId: 'com.bacsonlx.ninetripodcauldrons',
  productName: '九鼎',
  directories: { output: 'out/installer' },
  win: {
    target: [{ target: 'nsis', arch: ['x64'] }],
    executableName: 'nine-tripod-cauldrons',
    signAndEditExecutable: false,
  },
  nsis: {
    oneClick: false,
    perMachine: false,
    allowToChangeInstallationDirectory: true,
    createDesktopShortcut: true,
    createStartMenuShortcut: true,
    deleteAppDataOnUninstall: false,
    differentialPackage: false,
    artifactName: 'NineTripodCauldrons-Setup-${version}-${arch}.${ext}',
  },
  publish: null,
};
