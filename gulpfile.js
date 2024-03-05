const gulp = require('gulp');
const util = require('gulp-util');
const minimist = require('minimist');
const path = require('path');
const del = require('del');
const coffee = require('gulp-coffee');
const browserify = require('browserify');
const coffeeify = require('coffeeify');
const shim = require('browserify-shim');
const { Server: Karma } = require('karma');

const { version, standalone, filename } = require('./package');


const source = './src/**/*.coffee';
const options = minimist(process.argv.slice(2));

const moduleOutput = './lib';


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

let karmaConfig = {
  configFile: path.join(__dirname, 'karma.conf.js'),
  singleRun: true,
  sourceMaps: true
};

if (typeof options.browsers === 'string') {
  karmaConfig.browsers = options.browsers.split();
}

if (typeof options.grep === 'string') {
  karmaConfig.client = { args: ['--grep', options.grep] };
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
  new Karma(karmaConfig, karmaErrorHandler.bind(done)).start();
});

gulp.task('test-ci', (done) => {
  new Karma(Object.assign({}, karmaConfig, {
    browsers: ['Firefox']
  }), karmaErrorHandler.bind(done)).start();
});

gulp.task('test-watch', (done) => {
  var config = Object.assign({}, karmaConfig, {
    singleRun: false,
    autoWatch: true
  });

  new Karma(config, karmaErrorHandler.bind(done)).start();
});

gulp.task('test-debug', (done) => {
  var config = Object.assign({}, karmaConfig, {
    browsers: ['Chrome'],
    singleRun: false,
    autoWatch: true
  });

  new Karma(config, karmaErrorHandler.bind(done)).start();
});

gulp.task('ci', gulp.series(gulp.parallel(['test-ci'])));
