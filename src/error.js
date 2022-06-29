/*
 * decaffeinate suggestions:
 * DS001: Remove Babel/TypeScript constructor workaround
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
class BrainstemError extends Error {
  constructor(message) {
    super()
    this.name = 'BrainstemError';
    this.message = message || '';
  }
}

module.exports = Error;
