/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS205: Consider reworking code to avoid use of IIFEs
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore');
const Backbone = require('backbone');
Backbone.$ = require('jquery'); // TODO remove after upgrading to backbone 1.2+

const Error = require('./error');

class Utils {
  static warn(...args) {
    return typeof console !== 'undefined' && console !== null
      ? console.log('Error:', ...Array.from(args))
      : undefined;
  }

  static throwError(message) {
    message = `${message}`;
    const fragment = (() => {
      try {
        return Backbone.history != null
          ? Backbone.history.getFragment()
          : undefined;
      } catch (error) {}
    })();

    if (fragment) {
      message += `, fragment: ${fragment}`;
    }

    throw new Error(message);
  }

  static matches(obj1, obj2) {
    if (this.empty(obj1) && this.empty(obj2)) {
      return true;
    } else if (obj1 instanceof Array && obj2 instanceof Array) {
      return (
        obj1.length === obj2.length &&
        _.every(obj1, (value, index) => this.matches(value, obj2[index]))
      );
    } else if (obj1 instanceof Object && obj2 instanceof Object) {
      const obj1Keys = _(obj1).keys();
      const obj2Keys = _(obj2).keys();
      return (
        obj1Keys.length === obj2Keys.length &&
        _.every(obj1Keys, key => this.matches(obj1[key], obj2[key]))
      );
    } else {
      return String(obj1) === String(obj2);
    }
  }

  static empty(thing) {
    if (thing === null || thing === undefined || thing === '') {
      true;
    }
    if (thing instanceof Array) {
      return thing.length === 0 || (thing.length === 1 && this.empty(thing[0]));
    } else if (thing instanceof Object) {
      return _.keys(thing).length === 0;
    } else {
      return false;
    }
  }

  static extractArray(option, options) {
    let result = options[option];
    if (!(result instanceof Array)) {
      result = [result];
    }
    return _.compact(result);
  }

  static wrapObjects(array, optionalPredicate) {
    if (!optionalPredicate) {
      optionalPredicate = () => true;
    }

    const output = [];
    _(array).each(elem => {
      if (elem.constructor === Object) {
        return (() => {
          const result = [];
          for (let key in elem) {
            const value = elem[key];
            const o = {};

            if (
              (this.isPojo(value) ||
                value instanceof Array ||
                typeof value === 'string') &&
              optionalPredicate(value)
            ) {
              o[key] = this.wrapObjects(
                value instanceof Array ? value : [value]
              );
            } else {
              o[key] = value;
            }

            result.push(output.push(o));
          }
          return result;
        })();
      } else {
        const o = {};
        o[elem] = [];
        return output.push(o);
      }
    });
    return output;
  }

  static wrapError(collection, options) {
    const { error } = options;
    return (options.error = function(response) {
      if (error) {
        error(collection, response, options);
      }
      return collection.trigger('error', collection, response, options);
    });
  }

  static isPojo(obj) {
    const proto = Object.prototype;
    const gpo = Object.getPrototypeOf;

    if (obj === null || typeof obj !== 'object') {
      return false;
    }

    return gpo(obj) === proto;
  }

  // Chunk is in underscore 1.9.1, but not 1.8.3, which we're currently on.
  static chunk(array, count) {
    if (!Array.isArray(array) || count === null || count < 1) {
      return [];
    }
    const result = [];
    let i = 0;
    while (i < array.length) {
      result.push(array.slice(i, (i += count)));
    }
    return result;
  }
}

module.exports = Utils;
