import gulp from 'gulp';
import minimist from 'minimist';
import rename from 'gulp-rename';
import path from 'path';
import del from 'del';
import coffee from 'gulp-coffee';
import stream from 'vinyl-source-stream';
import browserify from 'browserify';
import coffeeify from 'coffeeify';
import shim from 'browserify-shim';
import { Server as Karma } from 'karma';

import { standalone } from './package';
import { filename } from './package';


const source = './src/brainstem.coffee';
const options = minimist(process.argv.slice(2));

const moduleOutput = './lib';
const gemOutput = './vendor/assets/javascripts';


// Tasks

gulp.task('build-module', () => {
  return gulp.src('./src/**/*.coffee')
    .pipe(coffee())
    .pipe(gulp.dest(moduleOutput));
});

gulp.task('build-gem', () => {
  return browserify(source, {
    standalone,
    transform: [coffeeify, shim],
    extensions: ['.coffee']
  }).bundle()
    .pipe(stream(source))
    .pipe(rename(`${filename}.js`))
    .pipe(gulp.dest(gemOutput));
});

gulp.task('clean-module', () => {
  return del(`${moduleOutput}/**/*.js`);
});

gulp.task('clean-gem', () => {
  return del(`${gemOutput}/**/*.js`);
});


var karmaConfigFile = path.join(__dirname, 'karma.conf.js');

gulp.task('test', (done) => {
  new Karma({
    configFile: karmaConfigFile,
    singleRun: true
  }, done).start();
});

gulp.task('test-ci', (done) => {
  new Karma({
    configFile: karmaConfigFile,
    singleRun: true,
    browsers: ['Firefox']
  }, done).start();
});

gulp.task('test-watch', (done) => {
  var config = {
    configFile: karmaConfigFile,
    singleRun: false,
    autoWatch: true
  };

  if (typeof options.browsers === 'string' && options.browsers.length) {
    config.browsers = options.browsers.split();
  }

  new Karma(config, done).start();
});

