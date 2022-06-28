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
      'spec/helpers/**/*.coffee',
      'spec/**/*-behavior.coffee',
      'spec/**/*-spec.coffee'
    ],

    preprocessors: {
      'src/**/*.js': ['browserify', 'sourcemap'],
      'spec/**/*.js': ['browserify', 'sourcemap'],
      'src/**/*.coffee': ['browserify', 'sourcemap'],
      'spec/**/*.coffee': ['browserify', 'sourcemap'],
    },

    browserify: {
      extensions: ['.js', '.coffee'],
      transform: ['babelify', 'coffeeify'],
      watch: true,
      debug: true
    }
  });
};
