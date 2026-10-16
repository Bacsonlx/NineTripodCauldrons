const { module: moduleConfig, resolve } = require('./webpack.main.config.cjs');

module.exports = {
  devtool: 'source-map',
  module: moduleConfig,
  resolve,
};
