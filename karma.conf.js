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
      'karma-phantomjs-launcher',
      'karma-chrome-launcher',
      'karma-firefox-launcher',
      'karma-browserify',
      'karma-sourcemap-loader'
    ],

    browsers: ['PhantomJS'],

    frameworks: ['jasmine', 'sinon', 'browserify'],

    reporters: ['spec'],

    files: [
      'spec/helpers/**/*.coffee',
      'spec/**/*-behavior.coffee',
      'spec/**/*-spec.coffee'
    ],

    preprocessors: {
      'src/**/*.coffee': ['browserify', 'sourcemap'],
      'spec/**/*.coffee': ['browserify', 'sourcemap']
    },

    browserify: {
      extensions: ['.coffee'],
      transform: ['coffeeify'],
      watch: true,
      debug: true
    }
  });
};
