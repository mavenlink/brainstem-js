/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require('underscore');
const Backbone = require('backbone');
Backbone.$ = require('jquery'); // TODO remove after upgrading to backbone 1.2+
const inflection = require('inflection');

const AbstractLoader = require('./abstract-loader');

class ModelLoader extends AbstractLoader {
  //
  // Accessors

  getModel() {
    return this.externalObject;
  }

  //
  // Private

  // Accessors

  _getCollectionName() {
    return (this.loadOptions.name = inflection.pluralize(
      this.loadOptions.name
    ));
  }

  _getExpectationName() {
    return this.loadOptions.name;
  }

  _getModel() {
    return this.internalObject.constructor;
  }

  _getModelsForAssociation(association) {
    return this._modelsOrObj(this.internalObject.get(association));
  }

  // Control

  _createObjects() {
    const id = this.loadOptions.only[0];
    const storage = this.storageManager.storage(this._getCollectionName());
    const { model } = this.loadOptions;

    if (model && model.id) {
      storage.add(model, { remove: false });
    }

    return (this.internalObject = this.externalObject =
      storage.get(id) ||
      this.storageManager.createNewModel(this.loadOptions.name, { id }));
  }

  _updateStorageManagerFromResponse(resp) {
    let attributes;
    return (attributes = this.internalObject.parse(resp));
  }

  _updateObjects(object, data) {
    if (_.isArray(data) && data.length === 1) {
      data = data[0];
    }

    if (data instanceof Backbone.Model) {
      data = data.attributes;
    }

    return object.set(data);
  }
}

module.exports = ModelLoader;
