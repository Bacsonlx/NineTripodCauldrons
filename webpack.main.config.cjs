module.exports = {
  entry: './src/desktop/main.ts',
  devtool: 'source-map',
  module: {
    rules: [
      {
        test: /\.ts$/,
        exclude: /node_modules/,
        use: {
          loader: 'ts-loader',
          options: { transpileOnly: true, compilerOptions: { noEmit: false } },
        },
      },
    ],
  },
  resolve: { extensions: ['.ts', '.js'] },
};
