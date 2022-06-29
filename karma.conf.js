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
      'spec/helpers/**/*.js',
      'spec/**/*-behavior.js',
      'spec/**/*-spec.js'
    ],

    preprocessors: {
      'src/**/*.js': ['browserify', 'sourcemap'],
      'spec/**/*.js': ['browserify', 'sourcemap'],
    },

    browserify: {
      extensions: ['.js'],
      transform: ['babelify'],
      watch: true,
      debug: true
    }
  });
};
