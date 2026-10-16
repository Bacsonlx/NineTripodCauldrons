const { module: moduleConfig, resolve } = require('./webpack.main.config.cjs');

module.exports = {
  devtool: 'source-map',
  module: {
    rules: [
      ...moduleConfig.rules,
      { test: /\.(svg|png)$/, type: 'asset/resource', generator: { filename: 'assets/[name][ext]' } },
    ],
  },
  resolve,
};
