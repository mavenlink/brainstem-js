const _ = require('underscore');
const $ = require('jquery');
const Backbone = require('backbone');
Backbone.$ = require('jquery'); // TODO remove after upgrading to backbone 1.2+
const inflection = require('inflection');
const {knownResponseKeys} = require('./constants');

const Utils = require('./utils');
const StorageManager = require('./storage-manager');
const {debug} = require("karma-firefox-launcher/release.config");

const isDateAttr = key => key.indexOf('date') > -1 || /_at$/.test(key);

class Model extends Backbone.Model {
    preinitialize() {
        this.OPTION_KEYS = ['name', 'include', 'cacheKey'];
    }

    //
    // Class Methods

    // Retreive details about a named association.  This is a class method.
    //     Model.associationDetails("project") # => {}
    //     timeEntry.constructor.associationDetails("project") # => {}
    static associationDetails(association) {
        if (!this.associationDetailsCache) {
            this.associationDetailsCache = {};
        }
        if (this.associations && this.associations[association]) {
            return (
                this.associationDetailsCache[association] ||
                (this.associationDetailsCache[association] = (() => {
                    const associator = this.associations[association];
                    const isArray = _.isArray(associator);
                    if (isArray && associator.length > 1) {
                        return {
                            type: 'BelongsTo',
                            collectionName: associator,
                            key: `${association}_ref`,
                            polymorphic: true
                        };
                    } else if (isArray) {
                        return {
                            type: 'HasMany',
                            collectionName: associator[0],
                            key: `${inflection.singularize(association)}_ids`
                        };
                    } else {
                        return {
                            type: 'BelongsTo',
                            collectionName: associator,
                            key: `${association}_id`
                        };
                    }
                })())
            );
        }
    }

    get storageManager() {
        if (this._storageManager) return this._storageManager;
        this._storageManager = StorageManager.get();
        return this._storageManager;
    }


    // Parse ISO8601 attribute strings into date objects
    static parse(modelObject) {
        for (let k in modelObject) {
            // Date.parse will parse ISO 8601 in ECMAScript 5, but we include a shim for now
            const v = modelObject[k];
            if (
                isDateAttr(k) &&
                /^\d{4}-\d{2}-\d{2}T\d{2}\:\d{2}\:\d{2}([-+]\d{2}:\d{2}|Z)$/.test(v)
            ) {
                modelObject[k] = Date.parse(v);
            }
        }
        return modelObject;
    }

    //
    // Init

    constructor(attributes = {}, options = {}) {
        super();
        let cache;
        this._onAssociatedCollectionChange = this._onAssociatedCollectionChange.bind(this);
        this._linkCollection = this._linkCollection.bind(this);
        this._cleanUpAssociatedReferences = this._cleanUpAssociatedReferences.bind(this);

        try {
            cache = this.storageManager.storage(this.brainstemKey);
        } catch (error) {
        }

        if (
            options.cached !== false &&
            attributes.id &&
            this.brainstemKey &&
            cache
        ) {
            const existing = cache.get(attributes.id);
            const blacklist = options.blacklist || this._associationKeyBlacklist();
            const valid =
                existing != null
                    ? existing.set(_.omit(attributes, blacklist))
                    : undefined;

            if (valid) {
                return existing;
            }
        }

        super(...arguments);
    }

    _associationKeyBlacklist() {
        if (!this.constructor.associations) {
            return [];
        }

        return _.chain(this.constructor.associations)
            .keys()
            .map(association => this.constructor.associationDetails(association).key)
            .value();
    }

    //
    // Accessors

    // Override Model#get to access associations as well as fields.
    get(field, options = {}) {
        const details =  this.constructor.associationDetails && this.constructor.associationDetails(field);
        if (details) {
            let collectionName, id, model;
            if (details.type === 'BelongsTo') {
                const pointer = super.get(details.key); // project_id
                if (pointer) {
                    if (details.polymorphic) {
                        ({id} = pointer);
                        collectionName = pointer.key;
                    } else {
                        id = pointer;
                        ({collectionName} = details);
                    }

                    model = this.storageManager.storage(collectionName).get(pointer);

                    if (!model && !options.silent) {
                        Utils.throwError(`\
Unable to find ${field} with id ${id} in our cached ${
                            details.collectionName
                        } collection.
We know about ${this.storageManager
                            .storage(details.collectionName)
                            .pluck('id')
                            .join(', ')}\
`);
                    }

                    return model;
                }
            } else {
                let collectionOptions;
                const ids = super.get(details.key); // time_entry_ids
                const models = [];
                const notFoundIds = [];
                if (ids) {
                    for (id of ids) {
                        if (id === null || id === undefined) {
                            continue;
                        }
                        model = this.storageManager.storage(details.collectionName).get(id);
                        models.push(model);
                        if (!model) {
                            notFoundIds.push(id);
                        }
                    }
                    if (notFoundIds.length && !options.silent) {
                        Utils.throwError(`\
Unable to find ${field} with ids ${notFoundIds.join(', ')} in our
cached ${details.collectionName} collection.  We know about
${this.storageManager
                            .storage(details.collectionName)
                            .pluck('id')
                            .join(', ')}\
`);
                    }
                }
                if (options.order) {
                    const {klass} = this.storageManager.getCollectionDetails(
                        details.collectionName
                    );
                    const comparator = klass.getComparatorWithIdFailover(options.order);
                    collectionOptions = {comparator};
                } else {
                    collectionOptions = {};
                }
                if (options.link) {
                    return this._linkCollection(
                        details.collectionName,
                        models,
                        collectionOptions,
                        field
                    );
                } else {
                    return this.storageManager.createNewCollection(
                        details.collectionName,
                        models,
                        collectionOptions
                    );
                }
            }
        } else {
            return super.get(field);
        }
    }

    className() {
        return this.paramRoot;
    }

    //
    // Control

    fetch(options) {
        options = options ? _.clone(options) : {};

        const id = this.id || options.id;

        if (id) {
            options.only = [id];
        }
        options.parse = options.parse != null ? options.parse : true;
        options.name = options.name != null ? options.name : this.brainstemKey;
        options.cache = false;
        if (options.returnValues == null) {
            options.returnValues = {};
        }
        options.model = this;

        if (!options.name) {
            Utils.throwError(
                'Either model must have a brainstemKey defined or name option must be provided'
            );
        }

        Utils.wrapError(this, options);

        return this.storageManager
            .loadObject(options.name, options, {isCollection: false})
            .done(response => {
                return this.trigger('sync', response, options);
            })
            .promise(options.returnValues.jqXhr);
    }

    _cleanUpAssociatedReferences() {
        _.each(this.storageManager.collections, function (collection) {
                _.each(collection.modelKlass.associations, function (associator, reference) {
                        const associationKey = collection.modelKlass.associationDetails(reference).key;
                        if (this._collectionHasMany(associator)) {
                            return collection.storage.each(function (model) {
                                model.set(
                                    associationKey,
                                    _.without(model.get(associationKey), this.id)
                                );
                            }, this);
                        } else if (this._collectionBelongsTo(associator)) {
                            collection.storage.each(function (model) {
                                if (model.get(associationKey) === this.id) {
                                    return model.unset(associationKey);
                                }
                            }, this);
                        }
                    },
                    this
                );
            },
            this
        );
    };

    destroy(options) {
        this.on('destroy', this._cleanUpAssociatedReferences);
        return super.destroy(options);
    }

    // Handle create and update responses with JSON root keys
    parse(resp, xhr) {
        this.updateStorageManager(resp);
        const modelObject = this._parseResultsResponse(resp);
        return super.parse(this.constructor.parse(modelObject), xhr);
    }

    updateStorageManager(resp) {
        const results = resp['results'];
        if (_.isEmpty(results)) {
            return;
        }

        const keys = _.without(_.keys(resp), ...knownResponseKeys);
        const primaryModelKey = results[0]['key'];
        keys.splice(keys.indexOf(primaryModelKey), 1);
        keys.push(primaryModelKey);

        return (() => {
            const result = [];
            for (var underscoredModelName of keys) {
                var models = resp[underscoredModelName];
                result.push(
                    (() => {
                        const result1 = [];
                        for (let id in models) {
                            const attributes = models[id];
                            this.constructor.parse(attributes);
                            const collection = this.storageManager.storage(
                                underscoredModelName
                            );
                            const collectionModel = collection.get(id);
                            if (collectionModel) {
                                result1.push(collectionModel.set(attributes));
                            } else {
                                if (
                                    this.brainstemKey === underscoredModelName &&
                                    (this.isNew() || this.id === attributes.id)
                                ) {
                                    this.set(attributes);
                                    result1.push(collection.add(this));
                                } else {
                                    result1.push(collection.add(attributes));
                                }
                            }
                        }
                        return result1;
                    })()
                );
            }
            return result;
        })();
    }

    dependenciesAreLoaded(loadOptions) {
        return (
            this.associationsAreLoaded(loadOptions.thisLayerInclude) &&
            this.optionalFieldsAreLoaded(loadOptions.optionalFields)
        );
    }

    optionalFieldsAreLoaded(optionalFields) {
        if (optionalFields == null) {
            return true;
        }
        return _.all(optionalFields, optionalField =>
            this.attributes.hasOwnProperty(optionalField)
        );
    }

    // This method determines if all of the provided associations have been loaded for this model.  If no associations are
    // provided, all associations are assumed.
    //   model.associationsAreLoaded(["project", "task"]) # => true|false
    //   model.associationsAreLoaded() # => true|false
    associationsAreLoaded(associations) {
        if (!associations) {
            associations = _.keys(this.constructor.associations);
        }
        associations = _.filter(associations, association =>
            this.constructor.associationDetails(association)
        );

        return _.all(associations, association => {
            const details = this.constructor.associationDetails(association);
            const {key} = details;

            if (!_(this.attributes).has(key)) {
                return false;
            }

            const pointer = this.attributes[key];

            if (details.type === 'BelongsTo') {
                if (pointer === null) {
                    return true;
                } else if (details.polymorphic) {
                    return this.storageManager.storage(pointer.key).get(pointer.id);
                } else {
                    return this.storageManager
                        .storage(details.collectionName)
                        .get(pointer);
                }
            } else {
                return _.all(pointer, id => {
                    return this.storageManager.storage(details.collectionName).get(id);
                });
            }
        });
    }

    setLoaded(state, options) {
        if (options == null || options.trigger == null || !!options.trigger) {
            options = {trigger: true};
        }
        this.loaded = state;
        if (state && options.trigger) {
            return this.trigger('loaded', this);
        }
    }

    invalidateCache() {
        return (() => {
            const result = [];
            const object = this.storageManager.getCollectionDetails(this.brainstemKey)
                .cache;
            for (let cacheKey in object) {
                const cacheObject = object[cacheKey];
                if (_.find(cacheObject.results, result => result.id === this.id)) {
                    result.push((cacheObject.valid = false));
                } else {
                    result.push(undefined);
                }
            }
            return result;
        })();
    }

    toServerJSON(method, options) {
        const json = this.toJSON(options);
        let blacklist = this.defaultJSONBlacklist();

        switch (method) {
            case 'create':
                if (this.createJSONWhitelist) {
                    blacklist = _.difference(
                        Object.keys(this.attributes),
                        this.createJSONWhitelist()
                    );
                } else {
                    blacklist = blacklist.concat(this.createJSONBlacklist());
                }
                break;
            case 'update':
                if (this.updateJSONWhitelist) {
                    blacklist = _.difference(
                        Object.keys(this.attributes),
                        this.updateJSONWhitelist()
                    );
                } else {
                    blacklist = blacklist.concat(this.updateJSONBlacklist());
                }
                break;
        }

        for (let blacklistKey of blacklist) {
            delete json[blacklistKey];
        }

        return json;
    }

    defaultJSONBlacklist() {
        return ['id', 'created_at', 'updated_at'];
    }

    createJSONBlacklist() {
        return [];
    }

    updateJSONBlacklist() {
        return [];
    }

    //
    // Private

    clone() {
        return new this.constructor(this.attributes, {cached: false});
    }

    _parseResultsResponse(resp) {
        if (!resp['results']) {
            return resp;
        }

        if (resp['results'].length) {
            const {key} = resp['results'][0];
            const {id} = resp['results'][0];
            return resp[key][id];
        } else {
            return {};
        }
    }

    _linkCollection(collectionName, models, collectionOptions, field) {
        if (this._associatedCollections == null) {
            this._associatedCollections = {};
        }

        if (!this._associatedCollections[field]) {
            this._associatedCollections[
                field
                ] = this.storageManager.createNewCollection(
                collectionName,
                models,
                collectionOptions
            );
            this._associatedCollections[field].on(
                'add',
                function () {
                    return this._onAssociatedCollectionChange.call(
                        this,
                        field,
                        arguments
                    );
                }.bind(this)
            );
            this._associatedCollections[field].on(
                'remove',
                function () {
                    return this._onAssociatedCollectionChange.call(
                        this,
                        field,
                        arguments
                    );
                }.bind(this)
            );
        }

        return this._associatedCollections[field];
    }

    _onAssociatedCollectionChange(field, collectionChangeDetails) {
        return (this.attributes[
            this.constructor.associationDetails(field).key
            ] = collectionChangeDetails[1].pluck('id'));
    }

    _collectionHasMany(associator) {
        return (
            _.isArray(associator) &&
            _.find(
                associator,
                collectionName =>
                    inflection.singularize(collectionName) === this.className()
            )
        );
    }

    _collectionBelongsTo(associator) {
        return (
            !_.isArray(associator) &&
            inflection.singularize(associator) === this.className()
        );
    }
}

module.exports = Model;
