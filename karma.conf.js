module.exports = function (config) {
  config.set({

    port: 9876,

    logLevel: config.LOG_INFO,

    autoWatch: true,
    singleRun: false,
    colors: true,

    plugins: [
      'karma-jasmine',
      'karma-chrome-launcher',
      'karma-browserify'
    ],

    browsers: ['Chrome'],

    frameworks: ['jasmine', 'browserify'],

    files: [
      'spec/**/*.coffee'
    ],

    preprocessors: {
      'src/**/*.coffee': ['browserify'],
      'spec/**/*.coffee': ['browserify']
    },

    browserify: {
      extensions: ['.coffee'],
      transform: ['coffeeify'],
      watch: true,
      debug: true
    }

  });
};
