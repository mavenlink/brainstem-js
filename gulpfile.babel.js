import gulp from 'gulp';
import minimist from 'minimist';
import rename from 'gulp-rename';
import path from 'path';
import del from 'del';
import coffee from 'gulp-coffee';
import stream from 'vinyl-source-stream';
import browserify from 'browserify';
import coffeeify from 'coffeeify';
import { server as karma } from 'karma';

import { standalone } from './package';
import { filename } from './package';


const source = './src/brainstem.coffee';
const output = './lib';
const gemOutput = './vendor/assets/javascripts/';
const options = minimist(process.argv.slice(2));


// Tasks

gulp.task('prebuild', function () {
  return gulp.src('./src/**/*.coffee')
    .pipe(coffee())
    .pipe(gulp.dest(output));
});

gulp.task('build-gem', function () {
  return browserify(source, {
    standalone,
    transform: [coffeeify],
    extensions: ['.coffee']
  }).bundle()
    .pipe(stream(source))
    .pipe(rename(`${filename}.js`))
    .pipe(gulp.dest(gemOutput));
});

gulp.task('clean-gem', function () {
  return del(`${gemOutput}**/*.js`);
});


var karmaConfigFile = path.join(__dirname, 'karma.conf.js');

gulp.task('test', function (done) {
  karma.start({
    configFile: karmaConfigFile,
    singleRun: true
  }, done);
});

gulp.task('test-ci', function (done) {
  karma.start({
    configFile: karmaConfigFile,
    singleRun: true,
    browsers: ['Firefox']
  }, done);
});

gulp.task('test-watch', function (done) {
  var config = {
    configFile: karmaConfigFile,
    singleRun: false,
    autoWatch: true
  };

  if (typeof options.browsers === 'string' && options.browsers.length) {
    config.browsers = options.browsers.split();
  }

  karma.start(config, done);
});

