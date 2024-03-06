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
      {
        pattern: 'spec/helpers/**/*.coffee',
        type: 'js'
      },
      {
        pattern: 'spec/**/*-behavior.coffee',
        type: 'js'
      },
      {
        pattern: 'spec/**/*-spec.coffee',
        type: 'js'
      }
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
