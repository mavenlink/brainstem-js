import gulp from 'gulp';
import util from 'gulp-util';
import minimist from 'minimist';
import rename from 'gulp-rename';
import replace from 'gulp-replace';
import download from 'gulp-download';
import path from 'path';
import del from 'del';
import coffee from 'gulp-coffee';
import stream from 'vinyl-source-stream';
import browserify from 'browserify';
import coffeeify from 'coffeeify';
import shim from 'browserify-shim';
import coffeelint from 'gulp-coffeelint';
import { Server as Karma } from 'karma';

import { version, standalone, filename } from './package';


const source = './src/**/*.coffee';
const gemSource = './src/brainstem.coffee';
const options = minimist(process.argv.slice(2));

const moduleOutput = './lib';
const gemOutput = './vendor/assets/javascripts';

const styleguide = 'https://raw.githubusercontent.com/mavenlink/coffeescript-style-guide/master';
const lintConfig = 'coffeelint.json';


// Tasks

gulp.task('build-module', () => {
  return gulp.src(source)
    .pipe(coffee())
    .pipe(gulp.dest(moduleOutput))
    .on('error', util.log);
});

gulp.task('build-gem', () => {
  return browserify(gemSource, {
    standalone,
    transform: [coffeeify, shim],
    extensions: ['.coffee']
  }).bundle()
    .pipe(stream(gemSource))
    .pipe(rename(`${filename}.js`))
    .pipe(gulp.dest(gemOutput))
    .on('error', util.log);
});

gulp.task('version-gem', () => {
  const base = './lib/brainstem/js/';

  return gulp.src(path.join(base, 'version.rb'), { base : base })
    .pipe(replace(/(VERSION = ").*(")/, `$1${version}$2`))
    .pipe(gulp.dest(base));
});

gulp.task('publish-gem', ['build-gem', 'version-gem']);

gulp.task('fetch-styleguide', () => {
  const url = `${styleguide}/${lintConfig}`;

  return download(url).pipe(gulp.dest('.'));
});

gulp.task('coffeelint', ['fetch-styleguide'], () => {
  return gulp.src(source)
    .pipe(coffeelint())
    .pipe(coffeelint.reporter('coffeelint-stylish'))
    .pipe(coffeelint.reporter('fail'));
});

gulp.task('clean-module', () => {
  return del(`${moduleOutput}/**/*.js`);
});

gulp.task('clean-gem', () => {
  return del(`${gemOutput}/**/*.js`);
});

gulp.task('clean-styleguide', () => {
  return del(lintConfig);
});


let karmaConfig = {
  configFile: path.join(__dirname, 'karma.conf.js'),
  singleRun: true
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
    browsers: ['Firefox', 'PhantomJS']
  }), karmaErrorHandler.bind(done)).start();
});

gulp.task('test-watch', (done) => {
  var config = Object.assign({}, karmaConfig, {
    singleRun: false,
    autoWatch: true
  });

  new Karma(config, karmaErrorHandler.bind(done)).start();
});
