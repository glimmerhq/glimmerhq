const fs = require('fs');
const path = require('path');
const glob = require('glob');
const webpack = require('webpack');
const VueLoaderPlugin = require('vue-loader/lib/plugin');
const StatsWriterPlugin = require('webpack-stats-plugin').StatsWriterPlugin;
const CompressionPlugin = require('compression-webpack-plugin');
const MonacoWebpackPlugin = require('./plugins/monaco_webpack');
const BundleAnalyzerPlugin = require('webpack-bundle-analyzer').BundleAnalyzerPlugin;
const CopyWebpackPlugin = require('copy-webpack-plugin');
const vendorDllHash = require('./helpers/vendor_dll_hash');

const ROOT_PATH = path.resolve(__dirname, '..');
const VENDOR_DLL = process.env.WEBPACK_VENDOR_DLL && process.env.WEBPACK_VENDOR_DLL !== 'false';
const CACHE_PATH = process.env.WEBPACK_CACHE_PATH || path.join(ROOT_PATH, 'tmp/cache');
const IS_PRODUCTION = process.env.NODE_ENV === 'production';
const IS_DEV_SERVER = process.env.WEBPACK_DEV_SERVER === 'true';
const DEV_SERVER_HOST = process.env.DEV_SERVER_HOST || 'localhost';
const DEV_SERVER_PORT = parseInt(process.env.DEV_SERVER_PORT, 10) || 3808;
const DEV_SERVER_PUBLIC_ADDR = process.env.DEV_SERVER_PUBLIC_ADDR;
const DEV_SERVER_HTTPS = process.env.DEV_SERVER_HTTPS && process.env.DEV_SERVER_HTTPS !== 'false';
const DEV_SERVER_LIVERELOAD = IS_DEV_SERVER && process.env.DEV_SERVER_LIVERELOAD !== 'false';
const WEBPACK_REPORT = process.env.WEBPACK_REPORT && process.env.WEBPACK_REPORT !== 'false';
const WEBPACK_MEMORY_TEST =
  process.env.WEBPACK_MEMORY_TEST && process.env.WEBPACK_MEMORY_TEST !== 'false';
const NO_COMPRESSION = process.env.NO_COMPRESSION && process.env.NO_COMPRESSION !== 'false';
const NO_SOURCEMAPS = process.env.NO_SOURCEMAPS && process.env.NO_SOURCEMAPS !== 'false';

const VUE_VERSION = require('vue/package.json').version;
const VUE_LOADER_VERSION = require('vue-loader/package.json').version;
const WEBPACK_VERSION = require('webpack/package.json').version;

const devtool = IS_PRODUCTION ? 'source-map' : 'cheap-module-eval-source-map';

let autoEntriesCount = 0;
let watchAutoEntries = [];
const defaultEntries = ['./main'];

function generateEntries() {
  // generate automatic entry points
  const autoEntries = {};
  const autoEntriesMap = {};
  const pageEntries = glob.sync('pages/**/index.js', {
    cwd: path.join(ROOT_PATH, 'app/assets/javascripts'),
  });
  watchAutoEntries = [path.join(ROOT_PATH, 'app/assets/javascripts/pages/')];

  function generateAutoEntries(path, prefix = '.') {
    const chunkPath = path.replace(/\/index\.js$/, '');
    const chunkName = chunkPath.replace(/\//g, '.');
    autoEntriesMap[chunkName] = `${prefix}/${path}`;
  }

  pageEntries.forEach(path => generateAutoEntries(path));

  const autoEntryKeys = Object.keys(autoEntriesMap);
  autoEntriesCount = autoEntryKeys.length;

  // import ancestor entrypoints within their children
  autoEntryKeys.forEach(entry => {
    const entryPaths = [autoEntriesMap[entry]];
    const segments = entry.split('.');
    while (segments.pop()) {
      const ancestor = segments.join('.');
      if (autoEntryKeys.includes(ancestor)) {
        entryPaths.unshift(autoEntriesMap[ancestor]);
      }
    }
    autoEntries[entry] = defaultEntries.concat(entryPaths);
  });

  const manualEntries = {
    default: defaultEntries,
    // sentry: './sentry/index.js', Temporarily commented out to investigate performance: https://gitlab.com/gitlab-org/gitlab/-/issues/251179
    performance_bar: './performance_bar/index.js',
    chrome_84_icon_fix: './lib/chrome_84_icon_fix.js',
    jira_connect_app: './jira_connect/index.js',
  };

  return Object.assign(manualEntries, autoEntries);
}

const alias = {
  '~': path.join(ROOT_PATH, 'app/assets/javascripts'),
  emojis: path.join(ROOT_PATH, 'fixtures/emojis'),
  empty_states: path.join(ROOT_PATH, 'app/views/shared/empty_states'),
  icons: path.join(ROOT_PATH, 'app/views/shared/icons'),
  images: path.join(ROOT_PATH, 'app/assets/images'),
  vendor: path.join(ROOT_PATH, 'vendor/assets/javascripts'),
  vue$: 'vue/dist/vue.esm.js',
  spec: path.join(ROOT_PATH, 'spec/javascripts'),
  jest: path.join(ROOT_PATH, 'spec/frontend'),
  shared_queries: path.join(ROOT_PATH, 'app/graphql/queries'),

  // the following resolves files which are different between CE and EE
  ee_else_ce: path.join(ROOT_PATH, 'app/assets/javascripts'),

  // override loader path for icons.svg so we do not duplicate this asset
  '@gitlab/svgs/dist/icons.svg': path.join(
    ROOT_PATH,
    'app/assets/javascripts/lib/utils/icons_path.js',
  ),
};

if (!IS_PRODUCTION) {
  const fixtureDir = 'fixtures';

  Object.assign(alias, {
    test_fixtures: path.join(ROOT_PATH, `tmp/tests/frontend/${fixtureDir}`),
    test_helpers: path.join(ROOT_PATH, 'spec/frontend_integration/test_helpers'),
  });
}

let dll;

if (VENDOR_DLL && !IS_PRODUCTION) {
  const dllHash = vendorDllHash();
  const dllCachePath = path.join(ROOT_PATH, `tmp/cache/webpack-dlls/${dllHash}`);
  dll = {
    manifestPath: path.join(dllCachePath, 'vendor.dll.manifest.json'),
    cacheFrom: dllCachePath,
    cacheTo: path.join(ROOT_PATH, `public/assets/webpack/dll.${dllHash}/`),
    publicPath: `dll.${dllHash}/vendor.dll.bundle.js`,
    exists: null,
  };
}

module.exports = {
  mode: IS_PRODUCTION ? 'production' : 'development',

  context: path.join(ROOT_PATH, 'app/assets/javascripts'),

  entry: generateEntries,

  output: {
    path: path.join(ROOT_PATH, 'public/assets/webpack'),
    publicPath: '/assets/webpack/',
    filename: IS_PRODUCTION ? '[name].[contenthash:8].bundle.js' : '[name].bundle.js',
    chunkFilename: IS_PRODUCTION ? '[name].[contenthash:8].chunk.js' : '[name].chunk.js',
    globalObject: 'this', // allow HMR and web workers to play nice
  },

  resolve: {
    extensions: ['.js', '.gql', '.graphql'],
    alias,
  },

  module: {
    strictExportPresence: true,
    rules: [
      {
        type: 'javascript/auto',
        test: /\.mjs$/,
        use: [],
      },
      {
        test: /\.js$/,
        exclude: path =>
          /node_modules\/(?!tributejs)|node_modules|vendor[\\/]assets/.test(path) &&
          !/\.vue\.js/.test(path),
        loader: 'babel-loader',
        options: {
          cacheDirectory: path.join(CACHE_PATH, 'babel-loader'),
        },
      },
      {
        test: /\.vue$/,
        loader: 'vue-loader',
        options: {
          cacheDirectory: path.join(CACHE_PATH, 'vue-loader'),
          cacheIdentifier: [
            process.env.NODE_ENV || 'development',
            webpack.version,
            VUE_VERSION,
            VUE_LOADER_VERSION,
          ].join('|'),
        },
      },
      {
        test: /\.(graphql|gql)$/,
        exclude: /node_modules/,
        loader: 'graphql-tag/loader',
      },
      {
        test: /icons\.svg$/,
        loader: 'file-loader',
        options: {
          name: '[name].[contenthash:8].[ext]',
        },
      },
      {
        test: /\.svg$/,
        exclude: /icons\.svg$/,
        loader: 'raw-loader',
      },
      {
        test: /\.(gif|png|mp4)$/,
        loader: 'url-loader',
        options: { limit: 2048 },
      },
      {
        test: /_worker\.js$/,
        use: [
          {
            loader: 'worker-loader',
            options: {
              name: '[name].[contenthash:8].worker.js',
              inline: IS_DEV_SERVER,
            },
          },
          'babel-loader',
        ],
      },
      {
        test: /\.(worker(\.min)?\.js|pdf|bmpr)$/,
        exclude: /node_modules/,
        loader: 'file-loader',
        options: {
          name: '[name].[contenthash:8].[ext]',
        },
      },
      {
        test: /.css$/,
        use: [
          'vue-style-loader',
          {
            loader: 'css-loader',
            options: {
              modules: 'global',
              localIdentName: '[name].[contenthash:8].[ext]',
            },
          },
        ],
      },
      {
        test: /\.(eot|ttf|woff|woff2)$/,
        include: /node_modules\/(katex\/dist\/fonts|monaco-editor)/,
        loader: 'file-loader',
        options: {
          name: '[name].[contenthash:8].[ext]',
          esModule: false,
        },
      },
    ],
  },

  optimization: {
    // Replace 'hashed' with 'deterministic' in webpack 5
    moduleIds: 'hashed',
    runtimeChunk: 'single',
    splitChunks: {
      maxInitialRequests: 20,
      // In order to prevent firewalls tripping up: https://gitlab.com/gitlab-org/gitlab/-/issues/22648
      automaticNameDelimiter: '-',
      cacheGroups: {
        default: false,
        common: () => ({
          priority: 20,
          name: 'main',
          chunks: 'initial',
          minChunks: autoEntriesCount * 0.9,
        }),
        graphql: {
          priority: 16,
          name: 'graphql',
          chunks: 'all',
          test: /[\\/]node_modules[\\/][^\\/]*(immer|apollo|graphql|zen-observable)[^\\/]*[\\/]/,
          minChunks: 2,
          reuseExistingChunk: true,
        },
        monaco: {
          priority: 15,
          name: 'monaco',
          chunks: 'all',
          test: /[\\/]node_modules[\\/]monaco-editor[\\/]/,
          minChunks: 2,
          reuseExistingChunk: true,
        },
        echarts: {
          priority: 14,
          name: 'echarts',
          chunks: 'all',
          test: /[\\/]node_modules[\\/](echarts|zrender)[\\/]/,
          minChunks: 2,
          reuseExistingChunk: true,
        },
        security_reports: {
          priority: 13,
          name: 'security_reports',
          chunks: 'initial',
          test: /[\\/](vue_shared[\\/](security_reports|license_compliance)|security_dashboard)[\\/]/,
          minChunks: 2,
          reuseExistingChunk: true,
        },
        vendors: {
          priority: 10,
          chunks: 'async',
          test: /[\\/](node_modules|vendor[\\/]assets[\\/]javascripts)[\\/]/,
        },
        commons: {
          chunks: 'all',
          minChunks: 2,
          reuseExistingChunk: true,
        },
      },
    },
  },

  plugins: [
    // manifest filename must match config.webpack.manifest_filename
    // webpack-rails only needs assetsByChunkName to function properly
    new StatsWriterPlugin({
      filename: 'manifest.json',
      transform: function(data, opts) {
        const stats = opts.compiler.getStats().toJson({
          chunkModules: false,
          source: false,
          chunks: false,
          modules: false,
          assets: true,
          errors: !IS_PRODUCTION,
          warnings: !IS_PRODUCTION,
        });

        // tell our rails helper where to find the DLL files
        if (dll) {
          stats.dllAssets = dll.publicPath;
        }
        return JSON.stringify(stats, null, 2);
      },
    }),

    // enable vue-loader to use existing loader rules for other module types
    new VueLoaderPlugin(),

    // automatically configure monaco editor web workers
    new MonacoWebpackPlugin(),

    // fix legacy jQuery plugins which depend on globals
    new webpack.ProvidePlugin({
      $: 'jquery',
      jQuery: 'jquery',
      Popper: ['popper.js', 'default'],
      Alert: 'exports-loader?Alert!bootstrap/js/dist/alert',
      Button: 'exports-loader?Button!bootstrap/js/dist/button',
      Carousel: 'exports-loader?Carousel!bootstrap/js/dist/carousel',
      Collapse: 'exports-loader?Collapse!bootstrap/js/dist/collapse',
      Dropdown: 'exports-loader?Dropdown!bootstrap/js/dist/dropdown',
      Modal: 'exports-loader?Modal!bootstrap/js/dist/modal',
      Popover: 'exports-loader?Popover!bootstrap/js/dist/popover',
      Scrollspy: 'exports-loader?Scrollspy!bootstrap/js/dist/scrollspy',
      Tab: 'exports-loader?Tab!bootstrap/js/dist/tab',
      Tooltip: 'exports-loader?Tooltip!bootstrap/js/dist/tooltip',
      Util: 'exports-loader?Util!bootstrap/js/dist/util',
    }),

    // if DLLs are enabled, detect whether the DLL exists and create it automatically if necessary
    dll && {
      apply(compiler) {
        compiler.hooks.beforeCompile.tapAsync('DllAutoCompilePlugin', (params, callback) => {
          if (dll.exists) {
            callback();
          } else if (fs.existsSync(dll.manifestPath)) {
            console.log(`Using vendor DLL found at: ${dll.cacheFrom}`);
            dll.exists = true;
            callback();
          } else {
            console.log(
              `Warning: No vendor DLL found at: ${dll.cacheFrom}. Compiling DLL automatically.`,
            );

            const dllConfig = require('./webpack.vendor.config.js');
            const dllCompiler = webpack(dllConfig);

            dllCompiler.run((err, stats) => {
              if (err) {
                return callback(err);
              }

              const info = stats.toJson();

              if (stats.hasErrors()) {
                console.error(info.errors.join('\n\n'));
                return callback('DLL not compiled successfully.');
              }

              if (stats.hasWarnings()) {
                console.warn(info.warnings.join('\n\n'));
                console.warn('DLL compiled with warnings.');
              } else {
                console.log('DLL compiled successfully.');
              }

              dll.exists = true;
              callback();
            });
          }
        });
      },
    },

    // reference our compiled DLL modules
    dll &&
      new webpack.DllReferencePlugin({
        context: ROOT_PATH,
        manifest: dll.manifestPath,
      }),

    dll &&
      new CopyWebpackPlugin([
        {
          from: dll.cacheFrom,
          to: dll.cacheTo,
        },
      ]),

    new CopyWebpackPlugin([
      {
        from: path.join(ROOT_PATH, 'node_modules/pdfjs-dist/cmaps/'),
        to: path.join(ROOT_PATH, 'public/assets/webpack/cmaps/'),
      },
      {
        from: path.join(ROOT_PATH, 'node_modules/@sourcegraph/code-host-integration/'),
        to: path.join(ROOT_PATH, 'public/assets/webpack/sourcegraph/'),
        ignore: ['package.json'],
      },
      {
        from: path.join(
          ROOT_PATH,
          'node_modules/@gitlab/visual-review-tools/dist/visual_review_toolbar.js',
        ),
        to: path.join(ROOT_PATH, 'public/assets/webpack'),
      },
    ]),

    // compression can require a lot of compute time and is disabled in CI
    IS_PRODUCTION && !NO_COMPRESSION && new CompressionPlugin(),

    // WatchForChangesPlugin
    // TODO: publish this as a separate plugin
    IS_DEV_SERVER && {
      apply(compiler) {
        compiler.hooks.emit.tapAsync('WatchForChangesPlugin', (compilation, callback) => {
          const missingDeps = Array.from(compilation.missingDependencies);
          const nodeModulesPath = path.join(ROOT_PATH, 'node_modules');
          const hasMissingNodeModules = missingDeps.some(
            file => file.indexOf(nodeModulesPath) !== -1,
          );

          // watch for changes to missing node_modules
          if (hasMissingNodeModules) compilation.contextDependencies.add(nodeModulesPath);

          // watch for changes to automatic entrypoints
          watchAutoEntries.forEach(watchPath => compilation.contextDependencies.add(watchPath));

          // report our auto-generated bundle count
          console.log(
            `${autoEntriesCount} entries from '/pages' automatically added to webpack output.`,
          );

          callback();
        });
      },
    },

    // output the in-memory heap size upon compilation and exit
    WEBPACK_MEMORY_TEST && {
      apply(compiler) {
        compiler.hooks.emit.tapAsync('ReportMemoryConsumptionPlugin', (compilation, callback) => {
          console.log('Assets compiled...');
          if (global.gc) {
            console.log('Running garbage collection...');
            global.gc();
          } else {
            console.error(
              "WARNING: you must use the --expose-gc node option to accurately measure webpack's heap size",
            );
          }
          const memoryUsage = process.memoryUsage().heapUsed;
          const toMB = bytes => Math.floor(bytes / 1024 / 1024);

          console.log(`Webpack heap size: ${toMB(memoryUsage)} MB`);

          const webpackStatistics = {
            memoryUsage,
            date: Date.now(), // milliseconds
            commitSHA: process.env.CI_COMMIT_SHA,
            nodeVersion: process.versions.node,
            webpackVersion: WEBPACK_VERSION,
          };

          console.log(webpackStatistics);

          fs.writeFileSync(
            path.join(ROOT_PATH, 'webpack-dev-server.json'),
            JSON.stringify(webpackStatistics),
          );

          // exit in case we're running webpack-dev-server
          IS_DEV_SERVER && process.exit();
        });
      },
    },

    // enable HMR only in webpack-dev-server
    DEV_SERVER_LIVERELOAD && new webpack.HotModuleReplacementPlugin(),

    // optionally generate webpack bundle analysis
    WEBPACK_REPORT &&
      new BundleAnalyzerPlugin({
        analyzerMode: 'static',
        generateStatsFile: true,
        openAnalyzer: false,
        reportFilename: path.join(ROOT_PATH, 'webpack-report/index.html'),
        statsFilename: path.join(ROOT_PATH, 'webpack-report/stats.json'),
        statsOptions: {
          source: false,
        },
      }),

    /* Pikaday has a optional dependency to moment.
       We are currently not utilizing moment.
       Ignoring this import removes warning from our development build.
       Upstream reference:
       https://github.com/Pikaday/Pikaday/blob/5c1a7559be/pikaday.js#L14
    */
    new webpack.IgnorePlugin(/moment/, /pikaday/),
  ].filter(Boolean),

  devServer: {
    host: DEV_SERVER_HOST,
    port: DEV_SERVER_PORT,
    public: DEV_SERVER_PUBLIC_ADDR,
    https: DEV_SERVER_HTTPS,
    contentBase: false,
    stats: 'errors-only',
    hot: DEV_SERVER_LIVERELOAD,
    inline: DEV_SERVER_LIVERELOAD,
  },

  devtool: NO_SOURCEMAPS ? false : devtool,

  node: {
    fs: 'empty', // sqljs requires fs
    setImmediate: false,
  },
};
