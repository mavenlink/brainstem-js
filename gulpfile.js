const gulp = require('gulp');
const util = require('gulp-util');
const minimist = require('minimist');
const path = require('path');
const del = require('del');
const coffee = require('gulp-coffee');
const karma = require('karma');

const source = './src/**/*.coffee';
const options = minimist(process.argv.slice(2));

const moduleOutput = './lib';
const karmaServer = karma.Server;

// Tasks

gulp.task('build-module', () => {
  return gulp.src(source)
    .pipe(coffee())
    .pipe(gulp.dest(moduleOutput))
    .on('error', util.log);
});

gulp.task('clean-module', () => {
  return del(`${moduleOutput}/**/*.js`);
});

let configFilePath = path.join(__dirname, 'karma.conf.js');
let karmaConfigOptions = {
  singleRun: true,
  sourceMaps: true
};

let parsedKarmaConfig = karma.config.parseConfig(configFilePath, karmaConfigOptions, { throwErrors: true })

if (typeof options.browsers === 'string') {
  parsedKarmaConfig.browsers = options.browsers.split();
}

if (typeof options.grep === 'string') {
  parsedKarmaConfig.client = { args: ['--grep', options.grep] };
}

const karmaErrorHandler = function(code) {
  if (code === 1) {
    util.log(util.colors.red('Tests finished with failures.'));
    process.exit(1);
  } else {
    this();
  }
};

gulp.task('test', (done) => {
  new karmaServer(parsedKarmaConfig, karmaErrorHandler.bind(done)).start();
});

gulp.task('test-ci', (done) => {
  new karmaServer(Object.assign({}, parsedKarmaConfig, {
    browsers: ['Firefox']
  }), karmaErrorHandler.bind(done)).start();
});

gulp.task('test-watch', (done) => {
  let karmaConfigOptions = {
    singleRun: false,
    sourceMaps: true,
    autoWatch: true
  };

  let parsedKarmaConfig = karma.config.parseConfig(configFilePath, karmaConfigOptions, { throwErrors: true })

  new karmaServer(parsedKarmaConfig, karmaErrorHandler.bind(done)).start();
});

gulp.task('test-debug', (done) => {
  let karmaConfigOptions = {
    singleRun: false,
    sourceMaps: true,

  };

  let parsedKarmaConfig = karma.config.parseConfig(configFilePath, karmaConfigOptions, { throwErrors: true })

  var config = Object.assign({}, parsedKarmaConfig, {
    browsers: ['Chrome'],
  });

  new karmaServer(config, karmaErrorHandler.bind(done)).start();
});

gulp.task('ci', gulp.series(gulp.parallel(['test-ci'])));
