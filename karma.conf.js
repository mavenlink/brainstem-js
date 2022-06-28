module.exports = function (config) {
  config.set({

    port: 9876,

    logLevel: config.LOG_INFO,

    autoWatch: true,
    singleRun: false,
    colors: true,

    plugins: [
      'karma-jasmine',
      'karma-sinon',
      'karma-spec-reporter',
      'karma-chrome-launcher',
      'karma-firefox-launcher',
      'karma-browserify',
      'karma-sourcemap-loader'
    ],

    browsers: ['FirefoxHeadless'],

    frameworks: ['jasmine', 'sinon', 'browserify'],

    reporters: ['spec'],

    files: [
      'spec/helpers/**/*.coffee',
      'spec/**/*-behavior.coffee',
      'spec/**/*-spec.coffee'
    ],

    preprocessors: {
      'src/**/*.coffee': ['browserify', 'sourcemap'],
      'src/**/*.js': ['browserify', 'sourcemap'],
      'spec/**/*.coffee': ['browserify', 'sourcemap'],
      'spec/**/*.js': ['browserify', 'sourcemap'],
    },

    browserify: {
      extensions: ['.coffee', '.js'],
      transform: ['coffeeify', 'babelify'],
      watch: true,
      debug: true
    }
  });
};
