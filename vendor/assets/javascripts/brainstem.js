(function(f){if(typeof exports==="object"&&typeof module!=="undefined"){module.exports=f()}else if(typeof define==="function"&&define.amd){define([],f)}else{var g;if(typeof window!=="undefined"){g=window}else if(typeof global!=="undefined"){g=global}else if(typeof self!=="undefined"){g=self}else{g=this}g.Brainstem = f()}})(function(){var define,module,exports;return (function e(t,n,r){function s(o,u){if(!n[o]){if(!t[o]){var a=typeof require=="function"&&require;if(!u&&a)return a(o,!0);if(i)return i(o,!0);var f=new Error("Cannot find module '"+o+"'");throw f.code="MODULE_NOT_FOUND",f}var l=n[o]={exports:{}};t[o][0].call(l.exports,function(e){var n=t[o][1][e];return s(n?n:e)},l,l.exports,e,t,n,r)}return n[o].exports}var i=typeof require=="function"&&require;for(var o=0;o<r.length;o++)s(r[o]);return s})({1:[function(require,module,exports){
/*!
 * inflection
 * Copyright(c) 2011 Ben Lin <ben@dreamerslab.com>
 * MIT Licensed
 *
 * @fileoverview
 * A port of inflection-js to node.js module.
 */

( function ( root, factory ){
  if( typeof define === 'function' && define.amd ){
    define([], factory );
  }else if( typeof exports === 'object' ){
    module.exports = factory();
  }else{
    root.inflection = factory();
  }
}( this, function (){

  /**
   * @description This is a list of nouns that use the same form for both singular and plural.
   *              This list should remain entirely in lower case to correctly match Strings.
   * @private
   */
  var uncountable_words = [
    // 'access',
    'accommodation',
    'adulthood',
    'advertising',
    'advice',
    'aggression',
    'aid',
    'air',
    'aircraft',
    'alcohol',
    'anger',
    'applause',
    'arithmetic',
    // 'art',
    'assistance',
    'athletics',
    // 'attention',

    'bacon',
    'baggage',
    // 'ballet',
    // 'beauty',
    'beef',
    // 'beer',
    // 'behavior',
    'biology',
    // 'billiards',
    'blood',
    'botany',
    // 'bowels',
    'bread',
    // 'business',
    'butter',

    'carbon',
    'cardboard',
    'cash',
    'chalk',
    'chaos',
    'chess',
    'crossroads',
    'countryside',

    // 'damage',
    'dancing',
    // 'danger',
    'deer',
    // 'delight',
    // 'dessert',
    'dignity',
    'dirt',
    // 'distribution',
    'dust',

    'economics',
    'education',
    'electricity',
    // 'employment',
    // 'energy',
    'engineering',
    'enjoyment',
    // 'entertainment',
    'envy',
    'equipment',
    'ethics',
    'evidence',
    'evolution',

    // 'failure',
    // 'faith',
    'fame',
    'fiction',
    // 'fish',
    'flour',
    'flu',
    'food',
    // 'freedom',
    // 'fruit',
    'fuel',
    'fun',
    // 'funeral',
    'furniture',

    'gallows',
    'garbage',
    'garlic',
    // 'gas',
    'genetics',
    // 'glass',
    'gold',
    'golf',
    'gossip',
    'grammar',
    // 'grass',
    'gratitude',
    'grief',
    // 'ground',
    'guilt',
    'gymnastics',

    // 'hair',
    'happiness',
    'hardware',
    'harm',
    'hate',
    'hatred',
    'health',
    'heat',
    // 'height',
    'help',
    'homework',
    'honesty',
    'honey',
    'hospitality',
    'housework',
    'humour',
    'hunger',
    'hydrogen',

    'ice',
    'importance',
    'inflation',
    'information',
    // 'injustice',
    'innocence',
    // 'intelligence',
    'iron',
    'irony',

    'jam',
    // 'jealousy',
    // 'jelly',
    'jewelry',
    // 'joy',
    'judo',
    // 'juice',
    // 'justice',

    'karate',
    // 'kindness',
    'knowledge',

    // 'labour',
    'lack',
    // 'land',
    'laughter',
    'lava',
    'leather',
    'leisure',
    'lightning',
    'linguine',
    'linguini',
    'linguistics',
    'literature',
    'litter',
    'livestock',
    'logic',
    'loneliness',
    // 'love',
    'luck',
    'luggage',

    'macaroni',
    'machinery',
    'magic',
    // 'mail',
    'management',
    'mankind',
    'marble',
    'mathematics',
    'mayonnaise',
    'measles',
    // 'meat',
    // 'metal',
    'methane',
    'milk',
    'money',
    // 'moose',
    'mud',
    'music',
    'mumps',

    'nature',
    'news',
    'nitrogen',
    'nonsense',
    'nurture',
    'nutrition',

    'obedience',
    'obesity',
    // 'oil',
    'oxygen',

    // 'paper',
    // 'passion',
    'pasta',
    'patience',
    // 'permission',
    'physics',
    'poetry',
    'pollution',
    'poverty',
    // 'power',
    'pride',
    // 'production',
    // 'progress',
    // 'pronunciation',
    'psychology',
    'publicity',
    'punctuation',

    // 'quality',
    // 'quantity',
    'quartz',

    'racism',
    // 'rain',
    // 'recreation',
    'relaxation',
    'reliability',
    'research',
    'respect',
    'revenge',
    'rice',
    'rubbish',
    'rum',

    'safety',
    // 'salad',
    // 'salt',
    // 'sand',
    // 'satire',
    'scenery',
    'seafood',
    'seaside',
    'series',
    'shame',
    'sheep',
    'shopping',
    // 'silence',
    'sleep',
    // 'slang'
    'smoke',
    'smoking',
    'snow',
    'soap',
    'software',
    'soil',
    // 'sorrow',
    // 'soup',
    'spaghetti',
    // 'speed',
    'species',
    // 'spelling',
    // 'sport',
    'steam',
    // 'strength',
    'stuff',
    'stupidity',
    // 'success',
    // 'sugar',
    'sunshine',
    'symmetry',

    // 'tea',
    'tennis',
    'thirst',
    'thunder',
    'timber',
    // 'time',
    // 'toast',
    // 'tolerance',
    // 'trade',
    'traffic',
    'transportation',
    // 'travel',
    'trust',

    // 'understanding',
    'underwear',
    'unemployment',
    'unity',
    // 'usage',

    'validity',
    'veal',
    'vegetation',
    'vegetarianism',
    'vengeance',
    'violence',
    // 'vision',
    'vitality',

    'warmth',
    // 'water',
    'wealth',
    'weather',
    // 'weight',
    'welfare',
    'wheat',
    // 'whiskey',
    // 'width',
    'wildlife',
    // 'wine',
    'wisdom',
    // 'wood',
    // 'wool',
    // 'work',

    // 'yeast',
    'yoga',

    'zinc',
    'zoology'
  ];

  /**
   * @description These rules translate from the singular form of a noun to its plural form.
   * @private
   */

  var regex = {
    plural : {
      men       : new RegExp( '^(m|wom)en$'                    , 'gi' ),
      people    : new RegExp( '(pe)ople$'                      , 'gi' ),
      children  : new RegExp( '(child)ren$'                    , 'gi' ),
      tia       : new RegExp( '([ti])a$'                       , 'gi' ),
      analyses  : new RegExp( '((a)naly|(b)a|(d)iagno|(p)arenthe|(p)rogno|(s)ynop|(t)he)ses$','gi' ),
      hives     : new RegExp( '(hi|ti)ves$'                    , 'gi' ),
      curves    : new RegExp( '(curve)s$'                      , 'gi' ),
      lrves     : new RegExp( '([lr])ves$'                     , 'gi' ),
      foves     : new RegExp( '([^fo])ves$'                    , 'gi' ),
      movies    : new RegExp( '(m)ovies$'                      , 'gi' ),
      aeiouyies : new RegExp( '([^aeiouy]|qu)ies$'             , 'gi' ),
      series    : new RegExp( '(s)eries$'                      , 'gi' ),
      xes       : new RegExp( '(x|ch|ss|sh)es$'                , 'gi' ),
      mice      : new RegExp( '([m|l])ice$'                    , 'gi' ),
      buses     : new RegExp( '(bus)es$'                       , 'gi' ),
      oes       : new RegExp( '(o)es$'                         , 'gi' ),
      shoes     : new RegExp( '(shoe)s$'                       , 'gi' ),
      crises    : new RegExp( '(cris|ax|test)es$'              , 'gi' ),
      octopi    : new RegExp( '(octop|vir)i$'                  , 'gi' ),
      aliases   : new RegExp( '(alias|canvas|status|campus)es$', 'gi' ),
      summonses : new RegExp( '^(summons)es$'                  , 'gi' ),
      oxen      : new RegExp( '^(ox)en'                        , 'gi' ),
      matrices  : new RegExp( '(matr)ices$'                    , 'gi' ),
      vertices  : new RegExp( '(vert|ind)ices$'                , 'gi' ),
      feet      : new RegExp( '^feet$'                         , 'gi' ),
      teeth     : new RegExp( '^teeth$'                        , 'gi' ),
      geese     : new RegExp( '^geese$'                        , 'gi' ),
      quizzes   : new RegExp( '(quiz)zes$'                     , 'gi' ),
      whereases : new RegExp( '^(whereas)es$'                  , 'gi' ),
      criteria  : new RegExp( '^(criteri)a$'                   , 'gi' ),
      genera    : new RegExp( '^genera$'                       , 'gi' ),
      ss        : new RegExp( 'ss$'                            , 'gi' ),
      s         : new RegExp( 's$'                             , 'gi' )
    },

    singular : {
      man       : new RegExp( '^(m|wom)an$'                  , 'gi' ),
      person    : new RegExp( '(pe)rson$'                    , 'gi' ),
      child     : new RegExp( '(child)$'                     , 'gi' ),
      ox        : new RegExp( '^(ox)$'                       , 'gi' ),
      axis      : new RegExp( '(ax|test)is$'                 , 'gi' ),
      octopus   : new RegExp( '(octop|vir)us$'               , 'gi' ),
      alias     : new RegExp( '(alias|status|canvas|campus)$', 'gi' ),
      summons   : new RegExp( '^(summons)$'                  , 'gi' ),
      bus       : new RegExp( '(bu)s$'                       , 'gi' ),
      buffalo   : new RegExp( '(buffal|tomat|potat)o$'       , 'gi' ),
      tium      : new RegExp( '([ti])um$'                    , 'gi' ),
      sis       : new RegExp( 'sis$'                         , 'gi' ),
      ffe       : new RegExp( '(?:([^f])fe|([lr])f)$'        , 'gi' ),
      hive      : new RegExp( '(hi|ti)ve$'                   , 'gi' ),
      aeiouyy   : new RegExp( '([^aeiouy]|qu)y$'             , 'gi' ),
      x         : new RegExp( '(x|ch|ss|sh)$'                , 'gi' ),
      matrix    : new RegExp( '(matr)ix$'                    , 'gi' ),
      vertex    : new RegExp( '(vert|ind)ex$'                , 'gi' ),
      mouse     : new RegExp( '([m|l])ouse$'                 , 'gi' ),
      foot      : new RegExp( '^foot$'                       , 'gi' ),
      tooth     : new RegExp( '^tooth$'                      , 'gi' ),
      goose     : new RegExp( '^goose$'                      , 'gi' ),
      quiz      : new RegExp( '(quiz)$'                      , 'gi' ),
      whereas   : new RegExp( '^(whereas)$'                  , 'gi' ),
      criterion : new RegExp( '^(criteri)on$'                , 'gi' ),
      genus     : new RegExp( '^genus$'                      , 'gi' ),
      s         : new RegExp( 's$'                           , 'gi' ),
      common    : new RegExp( '$'                            , 'gi' )
    }
  };

  var plural_rules = [

    // do not replace if its already a plural word
    [ regex.plural.men       ],
    [ regex.plural.people    ],
    [ regex.plural.children  ],
    [ regex.plural.tia       ],
    [ regex.plural.analyses  ],
    [ regex.plural.hives     ],
    [ regex.plural.curves    ],
    [ regex.plural.lrves     ],
    [ regex.plural.foves     ],
    [ regex.plural.aeiouyies ],
    [ regex.plural.series    ],
    [ regex.plural.movies    ],
    [ regex.plural.xes       ],
    [ regex.plural.mice      ],
    [ regex.plural.buses     ],
    [ regex.plural.oes       ],
    [ regex.plural.shoes     ],
    [ regex.plural.crises    ],
    [ regex.plural.octopi    ],
    [ regex.plural.aliases   ],
    [ regex.plural.summonses ],
    [ regex.plural.oxen      ],
    [ regex.plural.matrices  ],
    [ regex.plural.feet      ],
    [ regex.plural.teeth     ],
    [ regex.plural.geese     ],
    [ regex.plural.quizzes   ],
    [ regex.plural.whereases ],
    [ regex.plural.criteria  ],
    [ regex.plural.genera    ],

    // original rule
    [ regex.singular.man      , '$1en' ],
    [ regex.singular.person   , '$1ople' ],
    [ regex.singular.child    , '$1ren' ],
    [ regex.singular.ox       , '$1en' ],
    [ regex.singular.axis     , '$1es' ],
    [ regex.singular.octopus  , '$1i' ],
    [ regex.singular.alias    , '$1es' ],
    [ regex.singular.summons  , '$1es' ],
    [ regex.singular.bus      , '$1ses' ],
    [ regex.singular.buffalo  , '$1oes' ],
    [ regex.singular.tium     , '$1a' ],
    [ regex.singular.sis      , 'ses' ],
    [ regex.singular.ffe      , '$1$2ves' ],
    [ regex.singular.hive     , '$1ves' ],
    [ regex.singular.aeiouyy  , '$1ies' ],
    [ regex.singular.matrix   , '$1ices' ],
    [ regex.singular.vertex   , '$1ices' ],
    [ regex.singular.x        , '$1es' ],
    [ regex.singular.mouse    , '$1ice' ],
    [ regex.singular.foot     , 'feet' ],
    [ regex.singular.tooth    , 'teeth' ],
    [ regex.singular.goose    , 'geese' ],
    [ regex.singular.quiz     , '$1zes' ],
    [ regex.singular.whereas  , '$1es' ],
    [ regex.singular.criterion, '$1a' ],
    [ regex.singular.genus    , 'genera' ],

    [ regex.singular.s     , 's' ],
    [ regex.singular.common, 's' ]
  ];

  /**
   * @description These rules translate from the plural form of a noun to its singular form.
   * @private
   */
  var singular_rules = [

    // do not replace if its already a singular word
    [ regex.singular.man     ],
    [ regex.singular.person  ],
    [ regex.singular.child   ],
    [ regex.singular.ox      ],
    [ regex.singular.axis    ],
    [ regex.singular.octopus ],
    [ regex.singular.alias   ],
    [ regex.singular.summons ],
    [ regex.singular.bus     ],
    [ regex.singular.buffalo ],
    [ regex.singular.tium    ],
    [ regex.singular.sis     ],
    [ regex.singular.ffe     ],
    [ regex.singular.hive    ],
    [ regex.singular.aeiouyy ],
    [ regex.singular.x       ],
    [ regex.singular.matrix  ],
    [ regex.singular.mouse   ],
    [ regex.singular.foot    ],
    [ regex.singular.tooth   ],
    [ regex.singular.goose   ],
    [ regex.singular.quiz    ],
    [ regex.singular.whereas ],
    [ regex.singular.criterion ],
    [ regex.singular.genus ],

    // original rule
    [ regex.plural.men      , '$1an' ],
    [ regex.plural.people   , '$1rson' ],
    [ regex.plural.children , '$1' ],
    [ regex.plural.genera   , 'genus'],
    [ regex.plural.criteria , '$1on'],
    [ regex.plural.tia      , '$1um' ],
    [ regex.plural.analyses , '$1$2sis' ],
    [ regex.plural.hives    , '$1ve' ],
    [ regex.plural.curves   , '$1' ],
    [ regex.plural.lrves    , '$1f' ],
    [ regex.plural.foves    , '$1fe' ],
    [ regex.plural.movies   , '$1ovie' ],
    [ regex.plural.aeiouyies, '$1y' ],
    [ regex.plural.series   , '$1eries' ],
    [ regex.plural.xes      , '$1' ],
    [ regex.plural.mice     , '$1ouse' ],
    [ regex.plural.buses    , '$1' ],
    [ regex.plural.oes      , '$1' ],
    [ regex.plural.shoes    , '$1' ],
    [ regex.plural.crises   , '$1is' ],
    [ regex.plural.octopi   , '$1us' ],
    [ regex.plural.aliases  , '$1' ],
    [ regex.plural.summonses, '$1' ],
    [ regex.plural.oxen     , '$1' ],
    [ regex.plural.matrices , '$1ix' ],
    [ regex.plural.vertices , '$1ex' ],
    [ regex.plural.feet     , 'foot' ],
    [ regex.plural.teeth    , 'tooth' ],
    [ regex.plural.geese    , 'goose' ],
    [ regex.plural.quizzes  , '$1' ],
    [ regex.plural.whereases, '$1' ],

    [ regex.plural.ss, 'ss' ],
    [ regex.plural.s , '' ]
  ];

  /**
   * @description This is a list of words that should not be capitalized for title case.
   * @private
   */
  var non_titlecased_words = [
    'and', 'or', 'nor', 'a', 'an', 'the', 'so', 'but', 'to', 'of', 'at','by',
    'from', 'into', 'on', 'onto', 'off', 'out', 'in', 'over', 'with', 'for'
  ];

  /**
   * @description These are regular expressions used for converting between String formats.
   * @private
   */
  var id_suffix         = new RegExp( '(_ids|_id)$', 'g' );
  var underbar          = new RegExp( '_', 'g' );
  var space_or_underbar = new RegExp( '[\ _]', 'g' );
  var uppercase         = new RegExp( '([A-Z])', 'g' );
  var underbar_prefix   = new RegExp( '^_' );

  var inflector = {

  /**
   * A helper method that applies rules based replacement to a String.
   * @private
   * @function
   * @param {String} str String to modify and return based on the passed rules.
   * @param {Array: [RegExp, String]} rules Regexp to match paired with String to use for replacement
   * @param {Array: [String]} skip Strings to skip if they match
   * @param {String} override String to return as though this method succeeded (used to conform to APIs)
   * @returns {String} Return passed String modified by passed rules.
   * @example
   *
   *     this._apply_rules( 'cows', singular_rules ); // === 'cow'
   */
    _apply_rules : function ( str, rules, skip, override ){
      if( override ){
        str = override;
      }else{
        var ignore = ( inflector.indexOf( skip, str.toLowerCase()) > -1 );

        if( !ignore ){
          var i = 0;
          var j = rules.length;

          for( ; i < j; i++ ){
            if( str.match( rules[ i ][ 0 ])){
              if( rules[ i ][ 1 ] !== undefined ){
                str = str.replace( rules[ i ][ 0 ], rules[ i ][ 1 ]);
              }
              break;
            }
          }
        }
      }

      return str;
    },



  /**
   * This lets us detect if an Array contains a given element.
   * @public
   * @function
   * @param {Array} arr The subject array.
   * @param {Object} item Object to locate in the Array.
   * @param {Number} from_index Starts checking from this position in the Array.(optional)
   * @param {Function} compare_func Function used to compare Array item vs passed item.(optional)
   * @returns {Number} Return index position in the Array of the passed item.
   * @example
   *
   *     var inflection = require( 'inflection' );
   *
   *     inflection.indexOf([ 'hi','there' ], 'guys' ); // === -1
   *     inflection.indexOf([ 'hi','there' ], 'hi' ); // === 0
   */
    indexOf : function ( arr, item, from_index, compare_func ){
      if( !from_index ){
        from_index = -1;
      }

      var index = -1;
      var i     = from_index;
      var j     = arr.length;

      for( ; i < j; i++ ){
        if( arr[ i ]  === item || compare_func && compare_func( arr[ i ], item )){
          index = i;
          break;
        }
      }

      return index;
    },



  /**
   * This function adds pluralization support to every String object.
   * @public
   * @function
   * @param {String} str The subject string.
   * @param {String} plural Overrides normal output with said String.(optional)
   * @returns {String} Singular English language nouns are returned in plural form.
   * @example
   *
   *     var inflection = require( 'inflection' );
   *
   *     inflection.pluralize( 'person' ); // === 'people'
   *     inflection.pluralize( 'octopus' ); // === 'octopi'
   *     inflection.pluralize( 'Hat' ); // === 'Hats'
   *     inflection.pluralize( 'person', 'guys' ); // === 'guys'
   */
    pluralize : function ( str, plural ){
      return inflector._apply_rules( str, plural_rules, uncountable_words, plural );
    },



  /**
   * This function adds singularization support to every String object.
   * @public
   * @function
   * @param {String} str The subject string.
   * @param {String} singular Overrides normal output with said String.(optional)
   * @returns {String} Plural English language nouns are returned in singular form.
   * @example
   *
   *     var inflection = require( 'inflection' );
   *
   *     inflection.singularize( 'people' ); // === 'person'
   *     inflection.singularize( 'octopi' ); // === 'octopus'
   *     inflection.singularize( 'Hats' ); // === 'Hat'
   *     inflection.singularize( 'guys', 'person' ); // === 'person'
   */
    singularize : function ( str, singular ){
      return inflector._apply_rules( str, singular_rules, uncountable_words, singular );
    },


  /**
   * This function will pluralize or singularlize a String appropriately based on an integer value
   * @public
   * @function
   * @param {String} str The subject string.
   * @param {Number} count The number to base pluralization off of.
   * @param {String} singular Overrides normal output with said String.(optional)
   * @param {String} plural Overrides normal output with said String.(optional)
   * @returns {String} English language nouns are returned in the plural or singular form based on the count.
   * @example
   *
   *     var inflection = require( 'inflection' );
   *
   *     inflection.inflect( 'people' 1 ); // === 'person'
   *     inflection.inflect( 'octopi' 1 ); // === 'octopus'
   *     inflection.inflect( 'Hats' 1 ); // === 'Hat'
   *     inflection.inflect( 'guys', 1 , 'person' ); // === 'person'
   *     inflection.inflect( 'person', 2 ); // === 'people'
   *     inflection.inflect( 'octopus', 2 ); // === 'octopi'
   *     inflection.inflect( 'Hat', 2 ); // === 'Hats'
   *     inflection.inflect( 'person', 2, null, 'guys' ); // === 'guys'
   */
    inflect : function ( str, count, singular, plural ){
      count = parseInt( count, 10 );

      if( isNaN( count )) return str;

      if( count === 0 || count > 1 ){
        return inflector._apply_rules( str, plural_rules, uncountable_words, plural );
      }else{
        return inflector._apply_rules( str, singular_rules, uncountable_words, singular );
      }
    },



  /**
   * This function adds camelization support to every String object.
   * @public
   * @function
   * @param {String} str The subject string.
   * @param {Boolean} low_first_letter Default is to capitalize the first letter of the results.(optional)
   *                                 Passing true will lowercase it.
   * @returns {String} Lower case underscored words will be returned in camel case.
   *                  additionally '/' is translated to '::'
   * @example
   *
   *     var inflection = require( 'inflection' );
   *
   *     inflection.camelize( 'message_properties' ); // === 'MessageProperties'
   *     inflection.camelize( 'message_properties', true ); // === 'messageProperties'
   */
    camelize : function ( str, low_first_letter ){
      var str_path = str.split( '/' );
      var i        = 0;
      var j        = str_path.length;
      var str_arr, init_x, k, l, first;

      for( ; i < j; i++ ){
        str_arr = str_path[ i ].split( '_' );
        k       = 0;
        l       = str_arr.length;

        for( ; k < l; k++ ){
          if( k !== 0 ){
            str_arr[ k ] = str_arr[ k ].toLowerCase();
          }

          first = str_arr[ k ].charAt( 0 );
          first = low_first_letter && i === 0 && k === 0
            ? first.toLowerCase() : first.toUpperCase();
          str_arr[ k ] = first + str_arr[ k ].substring( 1 );
        }

        str_path[ i ] = str_arr.join( '' );
      }

      return str_path.join( '::' );
    },



  /**
   * This function adds underscore support to every String object.
   * @public
   * @function
   * @param {String} str The subject string.
   * @param {Boolean} all_upper_case Default is to lowercase and add underscore prefix.(optional)
   *                  Passing true will return as entered.
   * @returns {String} Camel cased words are returned as lower cased and underscored.
   *                  additionally '::' is translated to '/'.
   * @example
   *
   *     var inflection = require( 'inflection' );
   *
   *     inflection.underscore( 'MessageProperties' ); // === 'message_properties'
   *     inflection.underscore( 'messageProperties' ); // === 'message_properties'
   *     inflection.underscore( 'MP', true ); // === 'MP'
   */
    underscore : function ( str, all_upper_case ){
      if( all_upper_case && str === str.toUpperCase()) return str;

      var str_path = str.split( '::' );
      var i        = 0;
      var j        = str_path.length;

      for( ; i < j; i++ ){
        str_path[ i ] = str_path[ i ].replace( uppercase, '_$1' );
        str_path[ i ] = str_path[ i ].replace( underbar_prefix, '' );
      }

      return str_path.join( '/' ).toLowerCase();
    },



  /**
   * This function adds humanize support to every String object.
   * @public
   * @function
   * @param {String} str The subject string.
   * @param {Boolean} low_first_letter Default is to capitalize the first letter of the results.(optional)
   *                                 Passing true will lowercase it.
   * @returns {String} Lower case underscored words will be returned in humanized form.
   * @example
   *
   *     var inflection = require( 'inflection' );
   *
   *     inflection.humanize( 'message_properties' ); // === 'Message properties'
   *     inflection.humanize( 'message_properties', true ); // === 'message properties'
   */
    humanize : function ( str, low_first_letter ){
      str = str.toLowerCase();
      str = str.replace( id_suffix, '' );
      str = str.replace( underbar, ' ' );

      if( !low_first_letter ){
        str = inflector.capitalize( str );
      }

      return str;
    },



  /**
   * This function adds capitalization support to every String object.
   * @public
   * @function
   * @param {String} str The subject string.
   * @returns {String} All characters will be lower case and the first will be upper.
   * @example
   *
   *     var inflection = require( 'inflection' );
   *
   *     inflection.capitalize( 'message_properties' ); // === 'Message_properties'
   *     inflection.capitalize( 'message properties', true ); // === 'Message properties'
   */
    capitalize : function ( str ){
      str = str.toLowerCase();

      return str.substring( 0, 1 ).toUpperCase() + str.substring( 1 );
    },



  /**
   * This function replaces underscores with dashes in the string.
   * @public
   * @function
   * @param {String} str The subject string.
   * @returns {String} Replaces all spaces or underscores with dashes.
   * @example
   *
   *     var inflection = require( 'inflection' );
   *
   *     inflection.dasherize( 'message_properties' ); // === 'message-properties'
   *     inflection.dasherize( 'Message Properties' ); // === 'Message-Properties'
   */
    dasherize : function ( str ){
      return str.replace( space_or_underbar, '-' );
    },



  /**
   * This function adds titleize support to every String object.
   * @public
   * @function
   * @param {String} str The subject string.
   * @returns {String} Capitalizes words as you would for a book title.
   * @example
   *
   *     var inflection = require( 'inflection' );
   *
   *     inflection.titleize( 'message_properties' ); // === 'Message Properties'
   *     inflection.titleize( 'message properties to keep' ); // === 'Message Properties to Keep'
   */
    titleize : function ( str ){
      str         = str.toLowerCase().replace( underbar, ' ' );
      var str_arr = str.split( ' ' );
      var i       = 0;
      var j       = str_arr.length;
      var d, k, l;

      for( ; i < j; i++ ){
        d = str_arr[ i ].split( '-' );
        k = 0;
        l = d.length;

        for( ; k < l; k++){
          if( inflector.indexOf( non_titlecased_words, d[ k ].toLowerCase()) < 0 ){
            d[ k ] = inflector.capitalize( d[ k ]);
          }
        }

        str_arr[ i ] = d.join( '-' );
      }

      str = str_arr.join( ' ' );
      str = str.substring( 0, 1 ).toUpperCase() + str.substring( 1 );

      return str;
    },



  /**
   * This function adds demodulize support to every String object.
   * @public
   * @function
   * @param {String} str The subject string.
   * @returns {String} Removes module names leaving only class names.(Ruby style)
   * @example
   *
   *     var inflection = require( 'inflection' );
   *
   *     inflection.demodulize( 'Message::Bus::Properties' ); // === 'Properties'
   */
    demodulize : function ( str ){
      var str_arr = str.split( '::' );

      return str_arr[ str_arr.length - 1 ];
    },



  /**
   * This function adds tableize support to every String object.
   * @public
   * @function
   * @param {String} str The subject string.
   * @returns {String} Return camel cased words into their underscored plural form.
   * @example
   *
   *     var inflection = require( 'inflection' );
   *
   *     inflection.tableize( 'MessageBusProperty' ); // === 'message_bus_properties'
   */
    tableize : function ( str ){
      str = inflector.underscore( str );
      str = inflector.pluralize( str );

      return str;
    },



  /**
   * This function adds classification support to every String object.
   * @public
   * @function
   * @param {String} str The subject string.
   * @returns {String} Underscored plural nouns become the camel cased singular form.
   * @example
   *
   *     var inflection = require( 'inflection' );
   *
   *     inflection.classify( 'message_bus_properties' ); // === 'MessageBusProperty'
   */
    classify : function ( str ){
      str = inflector.camelize( str );
      str = inflector.singularize( str );

      return str;
    },



  /**
   * This function adds foreign key support to every String object.
   * @public
   * @function
   * @param {String} str The subject string.
   * @param {Boolean} drop_id_ubar Default is to seperate id with an underbar at the end of the class name,
                                 you can pass true to skip it.(optional)
   * @returns {String} Underscored plural nouns become the camel cased singular form.
   * @example
   *
   *     var inflection = require( 'inflection' );
   *
   *     inflection.foreign_key( 'MessageBusProperty' ); // === 'message_bus_property_id'
   *     inflection.foreign_key( 'MessageBusProperty', true ); // === 'message_bus_propertyid'
   */
    foreign_key : function ( str, drop_id_ubar ){
      str = inflector.demodulize( str );
      str = inflector.underscore( str ) + (( drop_id_ubar ) ? ( '' ) : ( '_' )) + 'id';

      return str;
    },



  /**
   * This function adds ordinalize support to every String object.
   * @public
   * @function
   * @param {String} str The subject string.
   * @returns {String} Return all found numbers their sequence like '22nd'.
   * @example
   *
   *     var inflection = require( 'inflection' );
   *
   *     inflection.ordinalize( 'the 1 pitch' ); // === 'the 1st pitch'
   */
    ordinalize : function ( str ){
      var str_arr = str.split( ' ' );
      var i       = 0;
      var j       = str_arr.length;

      for( ; i < j; i++ ){
        var k = parseInt( str_arr[ i ], 10 );

        if( !isNaN( k )){
          var ltd = str_arr[ i ].substring( str_arr[ i ].length - 2 );
          var ld  = str_arr[ i ].substring( str_arr[ i ].length - 1 );
          var suf = 'th';

          if( ltd != '11' && ltd != '12' && ltd != '13' ){
            if( ld === '1' ){
              suf = 'st';
            }else if( ld === '2' ){
              suf = 'nd';
            }else if( ld === '3' ){
              suf = 'rd';
            }
          }

          str_arr[ i ] += suf;
        }
      }

      return str_arr.join( ' ' );
    },

  /**
   * This function performs multiple inflection methods on a string
   * @public
   * @function
   * @param {String} str The subject string.
   * @param {Array} arr An array of inflection methods.
   * @returns {String}
   * @example
   *
   *     var inflection = require( 'inflection' );
   *
   *     inflection.transform( 'all job', [ 'pluralize', 'capitalize', 'dasherize' ]); // === 'All-jobs'
   */
    transform : function ( str, arr ){
      var i = 0;
      var j = arr.length;

      for( ;i < j; i++ ){
        var method = arr[ i ];

        if( this.hasOwnProperty( method )){
          str = this[ method ]( str );
        }
      }

      return str;
    }
  };

/**
 * @public
 */
  inflector.version = '1.10.0';

  return inflector;
}));

},{}],2:[function(require,module,exports){
module.exports = {
  Model: require('./model'),
  Collection: require('./collection'),
  StorageManager: require('./storage-manager')
};


},{"./collection":3,"./model":9,"./storage-manager":10}],3:[function(require,module,exports){
(function (global){
var $, Backbone, Collection, Utils, _,
  extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  hasProp = {}.hasOwnProperty;

$ = (typeof window !== "undefined" ? window['$'] : typeof global !== "undefined" ? global['$'] : null);

_ = (typeof window !== "undefined" ? window['_'] : typeof global !== "undefined" ? global['_'] : null);

Backbone = (typeof window !== "undefined" ? window['Backbone'] : typeof global !== "undefined" ? global['Backbone'] : null);

Backbone.$ = $;

Utils = require('./utils');

module.exports = Collection = (function(superClass) {
  extend(Collection, superClass);

  Collection.OPTION_KEYS = ['name', 'include', 'filters', 'page', 'perPage', 'limit', 'offset', 'order', 'search', 'cache', 'cacheKey', 'optionalFields'];

  Collection.getComparatorWithIdFailover = function(order) {
    var comp, direction, field, ref;
    ref = order.split(":"), field = ref[0], direction = ref[1];
    comp = this.getComparator(field);
    return function(a, b) {
      var ref1, result;
      if (direction.toLowerCase() === "desc") {
        ref1 = [a, b], b = ref1[0], a = ref1[1];
      }
      result = comp(a, b);
      if (result === 0) {
        return a.get('id') - b.get('id');
      } else {
        return result;
      }
    };
  };

  Collection.getComparator = function(field) {
    return function(a, b) {
      return a.get(field) - b.get(field);
    };
  };

  Collection.pickFetchOptions = function(options) {
    return _.pick(options, this.OPTION_KEYS);
  };

  Collection.prototype.lastFetchOptions = null;

  Collection.prototype.firstFetchOptions = null;

  Collection.prototype.model = function(attrs, options) {
    var Model;
    Model = require('./model');
    return new Model(attrs, options);
  };

  function Collection(models, options) {
    Collection.__super__.constructor.apply(this, arguments);
    this.storageManager = require('./storage-manager').get();
    if (options) {
      this.firstFetchOptions = Collection.pickFetchOptions(options);
    }
    this.setLoaded(false);
  }

  Collection.prototype.getServerCount = function() {
    var ref;
    return (ref = this._getCacheObject()) != null ? ref.count : void 0;
  };

  Collection.prototype.getWithAssocation = function(id) {
    return this.get(id);
  };

  Collection.prototype.fetch = function(options) {
    var loader, ref, ref1, ref2, xhr;
    options = options ? _.clone(options) : {};
    options.parse = (ref = options.parse) != null ? ref : true;
    options.name = (ref1 = options.name) != null ? ref1 : (ref2 = this.model) != null ? ref2.prototype.brainstemKey : void 0;
    if (options.returnValues == null) {
      options.returnValues = {};
    }
    if (!options.name) {
      Utils.throwError('Either collection must have model with brainstemKey defined or name option must be provided');
    }
    if (!this.firstFetchOptions) {
      this.firstFetchOptions = Collection.pickFetchOptions(options);
    }
    Utils.wrapError(this, options);
    loader = this.storageManager.loadObject(options.name, _.extend({}, this.firstFetchOptions, options));
    xhr = options.returnValues.jqXhr;
    this.trigger('request', this, xhr, options);
    return loader.then(function() {
      return loader.internalObject.models;
    }).done((function(_this) {
      return function(response) {
        var method;
        _this.lastFetchOptions = loader.externalObject.lastFetchOptions;
        if (options.add) {
          method = 'add';
        } else if (options.reset) {
          method = 'reset';
        } else {
          method = 'set';
        }
        _this[method](response, options);
        return _this.trigger('sync', _this, response, options);
      };
    })(this)).then(function() {
      return loader.externalObject;
    }).promise(xhr);
  };

  Collection.prototype.refresh = function(options) {
    if (options == null) {
      options = {};
    }
    return this.fetch(_.extend(this.lastFetchOptions, options, {
      cache: false
    }));
  };

  Collection.prototype.setLoaded = function(state, options) {
    if (!((options != null) && (options.trigger != null) && !options.trigger)) {
      options = {
        trigger: true
      };
    }
    this.loaded = state;
    if (state && options.trigger) {
      return this.trigger('loaded', this);
    }
  };

  Collection.prototype.update = function(models) {
    var backboneModel, i, len, model, modelInCollection, results;
    if (models.models != null) {
      models = models.models;
    }
    results = [];
    for (i = 0, len = models.length; i < len; i++) {
      model = models[i];
      if (this.model.parse != null) {
        model = this.model.parse(model);
      }
      backboneModel = this._prepareModel(model, {
        blacklist: []
      });
      if (backboneModel) {
        if (modelInCollection = this.get(backboneModel.id)) {
          results.push(modelInCollection.set(backboneModel.attributes));
        } else {
          results.push(this.add(backboneModel));
        }
      } else {
        results.push(Utils.warn("Unable to update collection with invalid model", model));
      }
    }
    return results;
  };

  Collection.prototype.reload = function(options) {
    var loadOptions;
    this.storageManager.reset();
    this.reset([], {
      silent: true
    });
    this.setLoaded(false);
    loadOptions = _.extend({}, this.lastFetchOptions, options, {
      page: 1,
      collection: this
    });
    return this.storageManager.loadCollection(this.lastFetchOptions.name, loadOptions);
  };

  Collection.prototype.loadNextPage = function(options) {
    var success;
    if (options == null) {
      options = {};
    }
    if (_.isFunction(options.success)) {
      success = options.success;
      delete options.success;
    }
    return this.getNextPage(_.extend(options, {
      add: true
    })).done((function(_this) {
      return function() {
        return typeof success === "function" ? success(_this, _this.hasNextPage()) : void 0;
      };
    })(this));
  };

  Collection.prototype.getPageIndex = function() {
    if (!this.lastFetchOptions) {
      return 1;
    }
    if (this.lastFetchOptions.offset != null) {
      return Math.ceil(this.lastFetchOptions.offset / this.lastFetchOptions.limit) + 1;
    } else {
      return this.lastFetchOptions.page;
    }
  };

  Collection.prototype.getNextPage = function(options) {
    if (options == null) {
      options = {};
    }
    return this.getPage(this.getPageIndex() + 1, options);
  };

  Collection.prototype.getPreviousPage = function(options) {
    if (options == null) {
      options = {};
    }
    return this.getPage(this.getPageIndex() - 1, options);
  };

  Collection.prototype.getFirstPage = function(options) {
    if (options == null) {
      options = {};
    }
    return this.getPage(1, options);
  };

  Collection.prototype.getLastPage = function(options) {
    if (options == null) {
      options = {};
    }
    return this.getPage(Infinity, options);
  };

  Collection.prototype.getPage = function(index, options) {
    var max, offset;
    if (options == null) {
      options = {};
    }
    this._canPaginate(true);
    options = _.extend(options, this.lastFetchOptions);
    if (index < 1) {
      index = 1;
    }
    if (this.lastFetchOptions.offset != null) {
      max = this._maxOffset();
      offset = this.lastFetchOptions.limit * index - this.lastFetchOptions.limit;
      options.offset = offset < max ? offset : max;
    } else {
      max = this._maxPage();
      options.page = index < max ? index : max;
    }
    return this.fetch(_.extend(options, {
      reset: true
    }));
  };

  Collection.prototype.hasNextPage = function() {
    if (!this._canPaginate()) {
      return false;
    }
    if (this.lastFetchOptions.offset != null) {
      if (this._maxOffset() > this.lastFetchOptions.offset) {
        return true;
      } else {
        return false;
      }
    } else {
      if (this._maxPage() > this.lastFetchOptions.page) {
        return true;
      } else {
        return false;
      }
    }
  };

  Collection.prototype.hasPreviousPage = function() {
    if (!this._canPaginate()) {
      return false;
    }
    if (this.lastFetchOptions.offset != null) {
      if (this.lastFetchOptions.offset > this.lastFetchOptions.limit) {
        return true;
      } else {
        return false;
      }
    } else {
      if (this.lastFetchOptions.page > 1) {
        return true;
      } else {
        return false;
      }
    }
  };

  Collection.prototype.invalidateCache = function() {
    var ref;
    return (ref = this._getCacheObject()) != null ? ref.valid = false : void 0;
  };

  Collection.prototype.toServerJSON = function(method) {
    return this.map(function(model) {
      return _.extend(model.toServerJSON(method), {
        id: model.id
      });
    });
  };

  Collection.prototype._canPaginate = function(throwError) {
    var count, options, throwOrReturn;
    if (throwError == null) {
      throwError = false;
    }
    options = this.lastFetchOptions;
    count = (function() {
      try {
        return this.getServerCount();
      } catch (undefined) {}
    }).call(this);
    throwOrReturn = function(message) {
      if (throwError) {
        return Utils.throwError(message);
      } else {
        return false;
      }
    };
    if (!options) {
      return throwOrReturn('(pagination) collection must have been fetched once');
    }
    if (!count) {
      return throwOrReturn('(pagination) collection must have a count');
    }
    if (!(options.perPage || options.limit)) {
      return throwOrReturn('(pagination) perPage or limit must be defined');
    }
    return true;
  };

  Collection.prototype._maxOffset = function() {
    var limit;
    limit = this.lastFetchOptions.limit;
    if (_.isUndefined(limit)) {
      Utils.throwError('(pagination) you must define limit when using offset');
    }
    return limit * Math.ceil(this.getServerCount() / limit) - limit;
  };

  Collection.prototype._maxPage = function() {
    var perPage;
    perPage = this.lastFetchOptions.perPage;
    if (_.isUndefined(perPage)) {
      Utils.throwError('(pagination) you must define perPage when using page');
    }
    return Math.ceil(this.getServerCount() / perPage);
  };

  Collection.prototype._getCacheObject = function() {
    var ref;
    if (this.lastFetchOptions) {
      return (ref = this.storageManager.getCollectionDetails(this.lastFetchOptions.name)) != null ? ref.cache[this.lastFetchOptions.cacheKey] : void 0;
    }
  };

  return Collection;

})(Backbone.Collection);


}).call(this,typeof global !== "undefined" ? global : typeof self !== "undefined" ? self : typeof window !== "undefined" ? window : {})
},{"./model":9,"./storage-manager":10,"./utils":12}],4:[function(require,module,exports){
var BrainstemError,
  extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  hasProp = {}.hasOwnProperty;

BrainstemError = (function(superClass) {
  extend(BrainstemError, superClass);

  function BrainstemError(message) {
    this.name = 'BrainstemError';
    this.message = message || '';
  }

  return BrainstemError;

})(Error);

module.exports = Error;


},{}],5:[function(require,module,exports){
(function (global){
var CollectionLoader, Error, Expectation, Utils, _;

_ = (typeof window !== "undefined" ? window['_'] : typeof global !== "undefined" ? global['_'] : null);

Error = require('./error');

CollectionLoader = require('./loaders/collection-loader');

Utils = require('./utils');

module.exports = Expectation = (function() {
  function Expectation(name, options, manager) {
    this.Model = require('./model');
    this.name = name;
    this.manager = manager;
    this.manager._setDefaultPageSettings(options);
    this.options = options;
    this.matches = [];
    this.recursive = false;
    this.triggerError = options.triggerError;
    this.count = options.count;
    this.immediate = options.immediate;
    delete options.immediate;
    this.associated = {};
    this.collections = {};
    this.requestQueue = [];
    if (this.options.response != null) {
      this.options.response(this);
    }
  }

  Expectation.prototype.handleRequest = function(loader) {
    var returnedData;
    this.matches.push(loader.originalOptions);
    if (!this.recursive) {
      loader.loadOptions.include = [];
    }
    if (this.triggerError != null) {
      loader._onServerLoadError(this.triggerError);
    }
    this._handleAssociations(loader);
    if (loader instanceof CollectionLoader) {
      returnedData = this._handleCollectionResults(loader);
    } else {
      returnedData = this._handleModelResults(loader);
    }
    return loader._onLoadSuccess(returnedData);
  };

  Expectation.prototype.recordRequest = function(loader) {
    if (this.immediate) {
      return this.handleRequest(loader);
    } else {
      return this.requestQueue.push(loader);
    }
  };

  Expectation.prototype.respond = function() {
    var i, len, ref, request;
    ref = this.requestQueue;
    for (i = 0, len = ref.length; i < len; i++) {
      request = ref[i];
      this.handleRequest(request);
    }
    return this.requestQueue = [];
  };

  Expectation.prototype.remove = function() {
    return this.disabled = true;
  };

  Expectation.prototype.lastMatch = function() {
    return this.matches[this.matches.length - 1];
  };

  Expectation.prototype.loaderOptionsMatch = function(loader) {
    if (this.disabled) {
      return false;
    }
    if (this.name !== loader._getExpectationName()) {
      return false;
    }
    this.manager._checkPageSettings(loader.originalOptions);
    return _.all(['include', 'only', 'order', 'filters', 'perPage', 'page', 'limit', 'offset', 'search'], (function(_this) {
      return function(optionType) {
        var expectedOption, option;
        if (_this.options[optionType] === '*') {
          return true;
        }
        option = _.compact(_.flatten([loader.originalOptions[optionType]]));
        expectedOption = _.compact(_.flatten([_this.options[optionType]]));
        if (optionType === 'include') {
          option = Utils.wrapObjects(option);
          expectedOption = Utils.wrapObjects(expectedOption);
        }
        return Utils.matches(option, expectedOption);
      };
    })(this));
  };

  Expectation.prototype._handleAssociations = function(_loader) {
    var key, ref, results, value, values;
    ref = this.associated;
    results = [];
    for (key in ref) {
      values = ref[key];
      if (!(values instanceof Array)) {
        values = [values];
      }
      results.push((function() {
        var i, len, results1;
        results1 = [];
        for (i = 0, len = values.length; i < len; i++) {
          value = values[i];
          results1.push(this.manager.storage(value.brainstemKey).update([value]));
        }
        return results1;
      }).call(this));
    }
    return results;
  };

  Expectation.prototype._handleCollectionResults = function(loader) {
    var cachedData, i, len, ref, ref1, result, returnedModels;
    if (!this.results) {
      return;
    }
    cachedData = {
      count: (ref = this.count) != null ? ref : this.results.length,
      results: this.results,
      valid: true
    };
    this.manager.getCollectionDetails(loader.loadOptions.name).cache[loader.loadOptions.cacheKey] = cachedData;
    ref1 = this.results;
    for (i = 0, len = ref1.length; i < len; i++) {
      result = ref1[i];
      if (result instanceof this.Model) {
        this.manager.storage(result.brainstemKey).update([result]);
      }
    }
    returnedModels = _.map(this.results, (function(_this) {
      return function(result) {
        if (result instanceof _this.Model) {
          return _this.manager.storage(result.brainstemKey).get(result.id);
        } else {
          return _this.manager.storage(result.key).get(result.id);
        }
      };
    })(this));
    return returnedModels;
  };

  Expectation.prototype._handleModelResults = function(loader) {
    var attributes, existingModel, key;
    if (!this.result) {
      return;
    }
    if (this.result instanceof this.Model) {
      key = this.result.brainstemKey;
      attributes = this.result.attributes;
    } else {
      key = this.result.key;
      attributes = _.omit(this.result, 'key');
    }
    if (!key) {
      throw Error('Brainstem key is required on the result (brainstemKey on model or key in JSON)');
    }
    existingModel = this.manager.storage(key).get(attributes.id);
    if (!existingModel) {
      existingModel = loader.getModel();
      this.manager.storage(key).add(existingModel);
    }
    existingModel.set(attributes);
    return existingModel;
  };

  return Expectation;

})();


}).call(this,typeof global !== "undefined" ? global : typeof self !== "undefined" ? self : typeof window !== "undefined" ? window : {})
},{"./error":4,"./loaders/collection-loader":7,"./model":9,"./utils":12}],6:[function(require,module,exports){
(function (global){
var $, AbstractLoader, Backbone, Utils, _,
  bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

$ = (typeof window !== "undefined" ? window['$'] : typeof global !== "undefined" ? global['$'] : null);

_ = (typeof window !== "undefined" ? window['_'] : typeof global !== "undefined" ? global['_'] : null);

Backbone = (typeof window !== "undefined" ? window['Backbone'] : typeof global !== "undefined" ? global['Backbone'] : null);

Backbone.$ = $;

Utils = require('../utils');

AbstractLoader = (function() {
  AbstractLoader.prototype.internalObject = null;

  AbstractLoader.prototype.externalObject = null;

  function AbstractLoader(options) {
    if (options == null) {
      options = {};
    }
    this._onLoadingCompleted = bind(this._onLoadingCompleted, this);
    this._onServerLoadError = bind(this._onServerLoadError, this);
    this._onServerLoadSuccess = bind(this._onServerLoadSuccess, this);
    this.storageManager = options.storageManager;
    this._deferred = $.Deferred();
    this._deferred.promise(this);
    if (options.loadOptions) {
      this.setup(options.loadOptions);
    }
  }


  /**
   * Setup the loader with a list of Brainstem specific loadOptions
   * @param  {object} loadOptions Brainstem specific loadOptions (filters, include, only, etc)
   * @return {object} externalObject that was created.
   */

  AbstractLoader.prototype.setup = function(loadOptions) {
    this._parseLoadOptions(loadOptions);
    this._createObjects();
    return this.externalObject;
  };


  /**
   * Returns the cache object from the storage manager.
   * @return {object} Object containing `count` and `results` that were cached.
   */

  AbstractLoader.prototype.getCacheObject = function() {
    return this.storageManager.getCollectionDetails(this._getCollectionName()).cache[this.loadOptions.cacheKey];
  };


  /**
   * Loads the model from memory or the server.
   * @return {object} the loader's `externalObject`
   */

  AbstractLoader.prototype.load = function() {
    var data;
    if (!this.loadOptions) {
      throw new Error('You must call #setup first or pass loadOptions into the constructor');
    }
    if (this.loadOptions.cache && (data = this._checkCacheForData())) {
      return data;
    } else {
      return this._loadFromServer();
    }
  };


  /**
   * Returns the name of the collection that this loader maps to and will update in the storageManager.
   * @return {string} name of the collection
   */

  AbstractLoader.prototype._getCollectionName = function() {
    throw new Error('Implement in your subclass');
  };


  /**
   * Returns the name that expectations will be stubbed with (story or stories etc)
   * @return {string} name of the stub
   */

  AbstractLoader.prototype._getExpectationName = function() {
    throw new Error('Implement in your subclass');
  };


  /**
   * This needs to return a constructor for the model that associations will be compared with.
   * This typically will be the current collection's model/current model constructor.
   * @return {Model}
   */

  AbstractLoader.prototype._getModel = function() {
    throw new Error('Implement in your subclass');
  };


  /**
   * This needs to return an array of models that correspond to the supplied association.
   * @return {array} models that are associated with this association
   */

  AbstractLoader.prototype._getModelsForAssociation = function(association) {
    throw new Error('Implement in your subclass');
  };


  /**
   * Returns an array of IDs that need to be loaded for this association.
   * @param  {string} association name of the association
   * @return {array} array of IDs to fetch for this association.
   */

  AbstractLoader.prototype._getIdsForAssociation = function(association) {
    var models;
    models = this._getModelsForAssociation(association);
    if (_.isArray(models)) {
      return _(models).chain().flatten().pluck("id").compact().uniq().sort().value();
    } else {
      return [models.id];
    }
  };


  /**
   * Sets up both the `internalObject` and `externalObject`.
   * In the case of models the `internalObject` and `externalObject` are the same.
   * In the case of collections the `internalObject` is a proxy object that updates
   * the `externalObject` when all loading is completed.
   */

  AbstractLoader.prototype._createObjects = function() {
    throw new Error('Implement in your subclass');
  };


  /**
   * Updates the object with the supplied data. Will be called:
   *   + after the server responds, `object` will be `internalObject` and
   *     data will be the result of `_updateStorageManagerFromResponse`
   *   + after all loading is complete, `object` will be the `externalObject`
   *     and data will be the `internalObject`
   * @param  {object} object object that will receive the data
   * @param  {object} data data that needs set on the object
   * @param  {boolean} silent whether or not to trigger loaded at the end of the update
   * @return {undefined}
   */

  AbstractLoader.prototype._updateObjects = function(object, data, silent) {
    if (silent == null) {
      silent = false;
    }
    throw new Error('Implement in your subclass');
  };


  /**
   * Parse supplied loadOptions, add defaults, transform them into
   * appropriate structures, and pull out important pieces.
   * @param  {object} loadOptions
   * @return {object} transformed loadOptions
   */

  AbstractLoader.prototype._parseLoadOptions = function(loadOptions) {
    var base, base1;
    if (loadOptions == null) {
      loadOptions = {};
    }
    this.originalOptions = _.clone(loadOptions);
    this.loadOptions = _.clone(loadOptions);
    this.loadOptions.include = Utils.wrapObjects(Utils.extractArray("include", this.loadOptions));
    this.loadOptions.optionalFields = Utils.extractArray("optionalFields", this.loadOptions);
    if ((base = this.loadOptions).filters == null) {
      base.filters = {};
    }
    this.loadOptions.thisLayerInclude = _.map(this.loadOptions.include, function(i) {
      return _.keys(i)[0];
    });
    if (this.loadOptions.only) {
      this.loadOptions.only = _.map(Utils.extractArray("only", this.loadOptions), function(id) {
        return String(id);
      });
    } else {
      this.loadOptions.only = null;
    }
    if ((base1 = this.loadOptions).cache == null) {
      base1.cache = true;
    }
    if (this.loadOptions.search) {
      this.loadOptions.cache = false;
    }
    this.loadOptions.cacheKey = this._buildCacheKey();
    this.cachedCollection = this.storageManager.storage(this._getCollectionName());
    return this.loadOptions;
  };


  /**
   * Builds a cache key to represent this object
   * @return {string} cache key
   */

  AbstractLoader.prototype._buildCacheKey = function() {
    var filterKeys, onlyIds;
    filterKeys = _.isObject(this.loadOptions.filters) && _.size(this.loadOptions.filters) > 0 ? JSON.stringify(this.loadOptions.filters) : '';
    onlyIds = (this.loadOptions.only || []).sort().join(',');
    return this.loadOptions.cacheKey = [this.loadOptions.order || "updated_at:desc", filterKeys, onlyIds, this.loadOptions.page, this.loadOptions.perPage, this.loadOptions.limit, this.loadOptions.offset, this.loadOptions.search].join('|');
  };


  /**
   * Checks to see if the current requested data is available in the caching layer.
   * If it is available then update the externalObject with that data (via `_onLoadSuccess`).
   * @return {[boolean|object]} returns false if not found otherwise returns the externalObject.
   */

  AbstractLoader.prototype._checkCacheForData = function() {
    var alreadyLoadedIds, cacheObject, subset;
    if (this.loadOptions.only != null) {
      alreadyLoadedIds = _.select(this.loadOptions.only, (function(_this) {
        return function(id) {
          var ref;
          return (ref = _this.cachedCollection.get(id)) != null ? ref.dependenciesAreLoaded(_this.loadOptions) : void 0;
        };
      })(this));
      if (alreadyLoadedIds.length === this.loadOptions.only.length) {
        this._onLoadSuccess(_.map(this.loadOptions.only, (function(_this) {
          return function(id) {
            return _this.cachedCollection.get(id);
          };
        })(this)));
        return this.externalObject;
      }
    } else {
      cacheObject = this.getCacheObject();
      if (cacheObject && cacheObject.valid) {
        subset = _.map(cacheObject.results, (function(_this) {
          return function(result) {
            return _this.storageManager.storage(result.key).get(result.id);
          };
        })(this));
        if (_.all(subset, (function(_this) {
          return function(model) {
            return model.dependenciesAreLoaded(_this.loadOptions);
          };
        })(this))) {
          this._onLoadSuccess(subset);
          return this.externalObject;
        }
      }
    }
    return false;
  };


  /**
   * Makes a GET request to the server via Backbone.sync with the built syncOptions.
   * @return {object} externalObject that will be updated when everything is complete.
   */

  AbstractLoader.prototype._loadFromServer = function() {
    var jqXhr;
    jqXhr = Backbone.sync.call(this.internalObject, 'read', this.internalObject, this._buildSyncOptions());
    if (this.loadOptions.returnValues) {
      this.loadOptions.returnValues.jqXhr = jqXhr;
    }
    return this.externalObject;
  };


  /**
   * Called when the server responds with data and needs to be persisted to the storageManager.
   * @param  {object} resp JSON data from the server
   * @return {[array|object]} array of models or model that was parsed.
   */

  AbstractLoader.prototype._updateStorageManagerFromResponse = function(resp) {
    throw new Error('Implement in your subclass');
  };


  /**
   * Called after the server responds with the first layer of includes to determine if any more loads are needed.
   * It will only make additional loads if there were IDs returned during this load for a given association.
   * @return {undefined}
   */

  AbstractLoader.prototype._calculateAdditionalIncludes = function() {
    var associationIds, associationInclude, associationName, hash, j, len, ref, results;
    this.additionalIncludes = [];
    ref = this.loadOptions.include;
    results = [];
    for (j = 0, len = ref.length; j < len; j++) {
      hash = ref[j];
      associationName = _.keys(hash)[0];
      associationIds = this._getIdsForAssociation(associationName);
      associationInclude = hash[associationName];
      if (associationIds.length && associationInclude.length) {
        results.push(this.additionalIncludes.push({
          name: associationName,
          ids: associationIds,
          include: associationInclude
        }));
      } else {
        results.push(void 0);
      }
    }
    return results;
  };


  /**
   * Loads the next layer of includes from the server.
   * When all loads are complete, it will call `_onLoadingCompleted` which will resolve this layer.
   * @return {undefined}
   */

  AbstractLoader.prototype._loadAdditionalIncludes = function() {
    var association, collectionName, j, len, loadOptions, promises, ref;
    promises = [];
    ref = this.additionalIncludes;
    for (j = 0, len = ref.length; j < len; j++) {
      association = ref[j];
      collectionName = this._getModel().associationDetails(association.name).collectionName;
      loadOptions = {
        cache: this.loadOptions.cache,
        only: association.ids,
        include: association.include,
        params: {
          apply_default_filters: false
        }
      };
      promises.push(this.storageManager.loadObject(collectionName, loadOptions));
    }
    return $.when.apply($, promises).done(this._onLoadingCompleted).fail(this._onServerLoadError);
  };


  /**
   * Generates the Brainstem specific options that are passed to Backbone.sync.
   * @return {object} options that are passed to Backbone.sync
   */

  AbstractLoader.prototype._buildSyncOptions = function() {
    var blacklist, options, ref, syncOptions;
    options = this.loadOptions;
    syncOptions = {
      data: {},
      parse: true,
      error: this._onServerLoadError,
      success: this._onServerLoadSuccess
    };
    if (options.thisLayerInclude.length) {
      syncOptions.data.include = options.thisLayerInclude.join(",");
    }
    if (options.only && this._shouldUseOnly()) {
      syncOptions.data.only = options.only.join(",");
    }
    if (options.order != null) {
      syncOptions.data.order = options.order;
    }
    if (options.search) {
      syncOptions.data.search = options.search;
    }
    if ((ref = this.loadOptions.optionalFields) != null ? ref.length : void 0) {
      syncOptions.data.optional_fields = this.loadOptions.optionalFields.join(",");
    }
    blacklist = ['include', 'only', 'order', 'per_page', 'page', 'limit', 'offset', 'search', 'optional_fields'];
    _(syncOptions.data).chain().extend(_(options.filters).omit(blacklist)).extend(_(options.params).omit(blacklist)).value();
    if (options.only == null) {
      if ((options.limit != null) && (options.offset != null)) {
        syncOptions.data.limit = options.limit;
        syncOptions.data.offset = options.offset;
      } else {
        syncOptions.data.per_page = options.perPage;
        syncOptions.data.page = options.page;
      }
    }
    return syncOptions;
  };


  /**
   * Decides whether or not the `only` filter should be applied in the syncOptions.
   * Models will not use the `only` filter as they use show routes.
   * @return {boolean} whether or not to use the `only` filter
   */

  AbstractLoader.prototype._shouldUseOnly = function() {
    return this.internalObject instanceof Backbone.Collection;
  };


  /**
   * Parses the result of model.get(associationName) to either return a collection's models
   * or the model itself.
   * @param  {object|Backbone.Collection} obj result of calling `.get` on a model with an association name.
   * @return {object|array} either a model object or an array of models from a collection.
   */

  AbstractLoader.prototype._modelsOrObj = function(obj) {
    if (obj instanceof Backbone.Collection) {
      return obj.models;
    } else if (obj instanceof Array) {
      return obj;
    } else if (obj) {
      return [obj];
    } else {
      return [];
    }
  };


  /**
   * Called when the Backbone.sync successfully responds from the server.
   * @param  {object} resp    JSON response from the server.
   * @param  {string} _status
   * @param  {object} _xhr    jQuery XHR object
   * @return {undefined}
   */

  AbstractLoader.prototype._onServerLoadSuccess = function(resp, _status, _xhr) {
    var data;
    data = this._updateStorageManagerFromResponse(resp);
    return this._onLoadSuccess(data);
  };


  /**
   * Called when the Backbone.sync has errored.
   * @param  {object} jqXhr
   * @param  {string} textStatus
   * @param  {string} errorThrown
   */

  AbstractLoader.prototype._onServerLoadError = function(jqXHR, textStatus, errorThrown) {
    return this._deferred.reject.apply(this, arguments);
  };


  /**
   * Updates the internalObject with the data in the storageManager and either loads more data or resolves this load.
   * Called after sync + storage manager updating.
   * @param  {array|object} data array of models or model from _updateStorageManagerFromResponse
   * @return {undefined}
   */

  AbstractLoader.prototype._onLoadSuccess = function(data) {
    this._updateObjects(this.internalObject, data, true);
    this._calculateAdditionalIncludes();
    if (this.additionalIncludes.length) {
      return this._loadAdditionalIncludes();
    } else {
      return this._onLoadingCompleted();
    }
  };


  /**
   * Called when all loading (including nested loads) are complete.
   * Updates the `externalObject` with the data that was gathered and resolves the promise.
   * @return {undefined}
   */

  AbstractLoader.prototype._onLoadingCompleted = function() {
    this._updateObjects(this.externalObject, this.internalObject);
    return this._deferred.resolve(this.externalObject);
  };

  return AbstractLoader;

})();

module.exports = AbstractLoader;


}).call(this,typeof global !== "undefined" ? global : typeof self !== "undefined" ? self : typeof window !== "undefined" ? window : {})
},{"../utils":12}],7:[function(require,module,exports){
(function (global){
var $, AbstractLoader, Collection, CollectionLoader, _,
  extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  hasProp = {}.hasOwnProperty;

$ = (typeof window !== "undefined" ? window['$'] : typeof global !== "undefined" ? global['$'] : null);

_ = (typeof window !== "undefined" ? window['_'] : typeof global !== "undefined" ? global['_'] : null);

Collection = require('../collection');

AbstractLoader = require('./abstract-loader');

CollectionLoader = (function(superClass) {
  extend(CollectionLoader, superClass);

  function CollectionLoader() {
    return CollectionLoader.__super__.constructor.apply(this, arguments);
  }

  CollectionLoader.prototype.getCollection = function() {
    return this.externalObject;
  };

  CollectionLoader.prototype._getCollectionName = function() {
    return this.loadOptions.name;
  };

  CollectionLoader.prototype._getExpectationName = function() {
    return this._getCollectionName();
  };

  CollectionLoader.prototype._getModel = function() {
    return this.internalObject.model;
  };

  CollectionLoader.prototype._getModelsForAssociation = function(association) {
    return this.internalObject.map((function(_this) {
      return function(m) {
        return _this._modelsOrObj(m.get(association));
      };
    })(this));
  };

  CollectionLoader.prototype._createObjects = function() {
    this.internalObject = this.storageManager.createNewCollection(this.loadOptions.name, []);
    this.externalObject = this.loadOptions.collection || this.storageManager.createNewCollection(this.loadOptions.name, []);
    this.externalObject.setLoaded(false);
    if (this.loadOptions.reset) {
      this.externalObject.reset([], {
        silent: false
      });
    }
    this.externalObject.lastFetchOptions = _.pick($.extend(true, {}, this.loadOptions), Collection.OPTION_KEYS);
    return this.externalObject.lastFetchOptions.include = this.originalOptions.include;
  };

  CollectionLoader.prototype._updateObjects = function(object, data, silent) {
    if (silent == null) {
      silent = false;
    }
    object.setLoaded(true, {
      trigger: false
    });
    if (data) {
      if (data.models != null) {
        data = data.models;
      }
      if (object.length) {
        object.add(data);
      } else {
        object.reset(data);
      }
    }
    if (!silent) {
      return object.setLoaded(true);
    }
  };

  CollectionLoader.prototype._updateStorageManagerFromResponse = function(resp) {
    var cachedData, i, keys, len, results, underscoredModelName;
    results = resp['results'];
    keys = _.reject(_.keys(resp), function(key) {
      return key === 'count' || key === 'results';
    });
    if (!_.isEmpty(results)) {
      if (keys.indexOf(this.loadOptions.name) !== -1) {
        keys.splice(keys.indexOf(this.loadOptions.name), 1);
      }
      keys.push(this.loadOptions.name);
    }
    for (i = 0, len = keys.length; i < len; i++) {
      underscoredModelName = keys[i];
      this.storageManager.storage(underscoredModelName).update(_(resp[underscoredModelName]).values());
    }
    cachedData = {
      count: resp.count,
      results: results,
      valid: true
    };
    this.storageManager.getCollectionDetails(this.loadOptions.name).cache[this.loadOptions.cacheKey] = cachedData;
    return _.map(results, (function(_this) {
      return function(result) {
        return _this.storageManager.storage(result.key).get(result.id);
      };
    })(this));
  };

  return CollectionLoader;

})(AbstractLoader);

module.exports = CollectionLoader;


}).call(this,typeof global !== "undefined" ? global : typeof self !== "undefined" ? self : typeof window !== "undefined" ? window : {})
},{"../collection":3,"./abstract-loader":6}],8:[function(require,module,exports){
(function (global){
var AbstractLoader, Backbone, ModelLoader, _, inflection,
  extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  hasProp = {}.hasOwnProperty;

_ = (typeof window !== "undefined" ? window['_'] : typeof global !== "undefined" ? global['_'] : null);

Backbone = (typeof window !== "undefined" ? window['Backbone'] : typeof global !== "undefined" ? global['Backbone'] : null);

Backbone.$ = (typeof window !== "undefined" ? window['$'] : typeof global !== "undefined" ? global['$'] : null);

inflection = require('inflection');

AbstractLoader = require('./abstract-loader');

ModelLoader = (function(superClass) {
  extend(ModelLoader, superClass);

  function ModelLoader() {
    return ModelLoader.__super__.constructor.apply(this, arguments);
  }

  ModelLoader.prototype.getModel = function() {
    return this.externalObject;
  };

  ModelLoader.prototype._getCollectionName = function() {
    return this.loadOptions.name = inflection.pluralize(this.loadOptions.name);
  };

  ModelLoader.prototype._getExpectationName = function() {
    return this.loadOptions.name;
  };

  ModelLoader.prototype._getModel = function() {
    return this.internalObject.constructor;
  };

  ModelLoader.prototype._getModelsForAssociation = function(association) {
    return this._modelsOrObj(this.internalObject.get(association));
  };

  ModelLoader.prototype._createObjects = function() {
    var id, model, storage;
    id = this.loadOptions.only[0];
    storage = this.storageManager.storage(this._getCollectionName());
    model = this.loadOptions.model;
    if (model && model.id) {
      storage.add(model, {
        remove: false
      });
    }
    return this.internalObject = this.externalObject = storage.get(id) || this.storageManager.createNewModel(this.loadOptions.name, {
      id: id
    });
  };

  ModelLoader.prototype._updateStorageManagerFromResponse = function(resp) {
    var attributes;
    return attributes = this.internalObject.parse(resp);
  };

  ModelLoader.prototype._updateObjects = function(object, data) {
    if (_.isArray(data) && data.length === 1) {
      data = data[0];
    }
    if (data instanceof Backbone.Model) {
      data = data.attributes;
    }
    return object.set(data);
  };

  return ModelLoader;

})(AbstractLoader);

module.exports = ModelLoader;


}).call(this,typeof global !== "undefined" ? global : typeof self !== "undefined" ? self : typeof window !== "undefined" ? window : {})
},{"./abstract-loader":6,"inflection":1}],9:[function(require,module,exports){
(function (global){
var Backbone, Model, StorageManager, Utils, _, inflection,
  bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  hasProp = {}.hasOwnProperty;

_ = (typeof window !== "undefined" ? window['_'] : typeof global !== "undefined" ? global['_'] : null);

Backbone = (typeof window !== "undefined" ? window['Backbone'] : typeof global !== "undefined" ? global['Backbone'] : null);

Backbone.$ = (typeof window !== "undefined" ? window['$'] : typeof global !== "undefined" ? global['$'] : null);

inflection = require('inflection');

Utils = require('./utils');

StorageManager = require('./storage-manager');

Model = (function(superClass) {
  extend(Model, superClass);

  Model.OPTION_KEYS = ['name', 'include', 'cacheKey'];

  Model.associationDetails = function(association) {
    var base;
    this.associationDetailsCache || (this.associationDetailsCache = {});
    if (this.associations && this.associations[association]) {
      return (base = this.associationDetailsCache)[association] || (base[association] = (function(_this) {
        return function() {
          var associator, isArray;
          associator = _this.associations[association];
          isArray = _.isArray(associator);
          if (isArray && associator.length > 1) {
            return {
              type: "BelongsTo",
              collectionName: associator,
              key: association + "_ref",
              polymorphic: true
            };
          } else if (isArray) {
            return {
              type: "HasMany",
              collectionName: associator[0],
              key: (inflection.singularize(association)) + "_ids"
            };
          } else {
            return {
              type: "BelongsTo",
              collectionName: associator,
              key: association + "_id"
            };
          }
        };
      })(this)());
    }
  };

  Model.parse = function(modelObject) {
    var k, v;
    for (k in modelObject) {
      v = modelObject[k];
      if (/^\d{4}-\d{2}-\d{2}T\d{2}\:\d{2}\:\d{2}[-+]\d{2}:\d{2}$/.test(v)) {
        modelObject[k] = Date.parse(v);
      }
    }
    return modelObject;
  };

  function Model(attributes, options) {
    var blacklist, existing, valid;
    if (attributes == null) {
      attributes = {};
    }
    if (options == null) {
      options = {};
    }
    this._onAssociatedCollectionChange = bind(this._onAssociatedCollectionChange, this);
    this.storageManager = StorageManager.get();
    if (options.cached !== false && attributes.id && this.brainstemKey) {
      existing = this.storageManager.storage(this.brainstemKey).get(attributes.id);
      blacklist = options.blacklist || this._associationKeyBlacklist();
      valid = existing != null ? existing.set(_.omit(attributes, blacklist)) : void 0;
      if (valid) {
        return existing;
      }
    }
    Model.__super__.constructor.apply(this, arguments);
  }

  Model.prototype._associationKeyBlacklist = function() {
    if (!this.constructor.associations) {
      return [];
    }
    return _.chain(this.constructor.associations).keys().map((function(_this) {
      return function(association) {
        return _this.constructor.associationDetails(association).key;
      };
    })(this)).value();
  };

  Model.prototype.get = function(field, options) {
    var collectionName, collectionOptions, comparator, details, i, id, ids, len, model, models, notFoundIds, pointer;
    if (options == null) {
      options = {};
    }
    if (details = this.constructor.associationDetails(field)) {
      if (details.type === "BelongsTo") {
        pointer = Model.__super__.get.call(this, details.key);
        if (pointer) {
          if (details.polymorphic) {
            id = pointer.id;
            collectionName = pointer.key;
          } else {
            id = pointer;
            collectionName = details.collectionName;
          }
          model = this.storageManager.storage(collectionName).get(pointer);
          if (!model && !options.silent) {
            Utils.throwError("Unable to find " + field + " with id " + id + " in our cached " + details.collectionName + " collection.  We know about " + (this.storageManager.storage(details.collectionName).pluck("id").join(", ")));
          }
          return model;
        }
      } else {
        ids = Model.__super__.get.call(this, details.key);
        models = [];
        notFoundIds = [];
        if (ids) {
          for (i = 0, len = ids.length; i < len; i++) {
            id = ids[i];
            model = this.storageManager.storage(details.collectionName).get(id);
            models.push(model);
            if (!model) {
              notFoundIds.push(id);
            }
          }
          if (notFoundIds.length && !options.silent) {
            Utils.throwError("Unable to find " + field + " with ids " + (notFoundIds.join(", ")) + " in our cached " + details.collectionName + " collection.  We know about " + (this.storageManager.storage(details.collectionName).pluck("id").join(", ")));
          }
        }
        if (options.order) {
          comparator = this.storageManager.getCollectionDetails(details.collectionName).klass.getComparatorWithIdFailover(options.order);
          collectionOptions = {
            comparator: comparator
          };
        } else {
          collectionOptions = {};
        }
        if (options.link) {
          return this._linkCollection(details.collectionName, models, collectionOptions, field);
        } else {
          return this.storageManager.createNewCollection(details.collectionName, models, collectionOptions);
        }
      }
    } else {
      return Model.__super__.get.call(this, field);
    }
  };

  Model.prototype.className = function() {
    return this.paramRoot;
  };

  Model.prototype.fetch = function(options) {
    var id, ref, ref1;
    options = options ? _.clone(options) : {};
    id = this.id || options.id;
    if (id) {
      options.only = [id];
    }
    options.parse = (ref = options.parse) != null ? ref : true;
    options.name = (ref1 = options.name) != null ? ref1 : this.brainstemKey;
    options.cache = false;
    if (options.returnValues == null) {
      options.returnValues = {};
    }
    options.model = this;
    if (!options.name) {
      Utils.throwError('Either model must have a brainstemKey defined or name option must be provided');
    }
    Utils.wrapError(this, options);
    return this.storageManager.loadObject(options.name, options, {
      isCollection: false
    }).done((function(_this) {
      return function(response) {
        return _this.trigger('sync', response, options);
      };
    })(this)).promise(options.returnValues.jqXhr);
  };

  Model.prototype.parse = function(resp, xhr) {
    var modelObject;
    this.updateStorageManager(resp);
    modelObject = this._parseResultsResponse(resp);
    return Model.__super__.parse.call(this, this.constructor.parse(modelObject), xhr);
  };

  Model.prototype.updateStorageManager = function(resp) {
    var attributes, collection, collectionModel, i, id, keys, len, models, primaryModelKey, results, results1, underscoredModelName;
    results = resp['results'];
    if (_.isEmpty(results)) {
      return;
    }
    keys = _.reject(_.keys(resp), function(key) {
      return key === 'count' || key === 'results';
    });
    primaryModelKey = results[0]['key'];
    keys.splice(keys.indexOf(primaryModelKey), 1);
    keys.push(primaryModelKey);
    results1 = [];
    for (i = 0, len = keys.length; i < len; i++) {
      underscoredModelName = keys[i];
      models = resp[underscoredModelName];
      results1.push((function() {
        var results2;
        results2 = [];
        for (id in models) {
          attributes = models[id];
          this.constructor.parse(attributes);
          collection = this.storageManager.storage(underscoredModelName);
          collectionModel = collection.get(id);
          if (collectionModel) {
            results2.push(collectionModel.set(attributes));
          } else {
            if (this.brainstemKey === underscoredModelName && (this.isNew() || this.id === attributes.id)) {
              this.set(attributes);
              results2.push(collection.add(this));
            } else {
              results2.push(collection.add(attributes));
            }
          }
        }
        return results2;
      }).call(this));
    }
    return results1;
  };

  Model.prototype.dependenciesAreLoaded = function(loadOptions) {
    return this.associationsAreLoaded(loadOptions.thisLayerInclude) && this.optionalFieldsAreLoaded(loadOptions.optionalFields);
  };

  Model.prototype.optionalFieldsAreLoaded = function(optionalFields) {
    if (optionalFields == null) {
      return true;
    }
    return _.all(optionalFields, (function(_this) {
      return function(optionalField) {
        return _this.attributes.hasOwnProperty(optionalField);
      };
    })(this));
  };

  Model.prototype.associationsAreLoaded = function(associations) {
    associations || (associations = _.keys(this.constructor.associations));
    associations = _.filter(associations, (function(_this) {
      return function(association) {
        return _this.constructor.associationDetails(association);
      };
    })(this));
    return _.all(associations, (function(_this) {
      return function(association) {
        var details, key, pointer;
        details = _this.constructor.associationDetails(association);
        key = details.key;
        if (!_(_this.attributes).has(key)) {
          return false;
        }
        pointer = _this.attributes[key];
        if (details.type === "BelongsTo") {
          if (pointer === null) {
            return true;
          } else if (details.polymorphic) {
            return _this.storageManager.storage(pointer.key).get(pointer.id);
          } else {
            return _this.storageManager.storage(details.collectionName).get(pointer);
          }
        } else {
          return _.all(pointer, function(id) {
            return _this.storageManager.storage(details.collectionName).get(id);
          });
        }
      };
    })(this));
  };

  Model.prototype.setLoaded = function(state, options) {
    if (!((options != null) && (options.trigger != null) && !options.trigger)) {
      options = {
        trigger: true
      };
    }
    this.loaded = state;
    if (state && options.trigger) {
      return this.trigger('loaded', this);
    }
  };

  Model.prototype.invalidateCache = function() {
    var cacheKey, cacheObject, ref, results1;
    ref = this.storageManager.getCollectionDetails(this.brainstemKey).cache;
    results1 = [];
    for (cacheKey in ref) {
      cacheObject = ref[cacheKey];
      if (_.find(cacheObject.results, (function(_this) {
        return function(result) {
          return result.id === _this.id;
        };
      })(this))) {
        results1.push(cacheObject.valid = false);
      } else {
        results1.push(void 0);
      }
    }
    return results1;
  };

  Model.prototype.toServerJSON = function(method, options) {
    var blacklist, blacklistKey, i, json, len;
    json = this.toJSON(options);
    blacklist = this.defaultJSONBlacklist();
    switch (method) {
      case "create":
        blacklist = blacklist.concat(this.createJSONBlacklist());
        break;
      case "update":
        blacklist = blacklist.concat(this.updateJSONBlacklist());
    }
    for (i = 0, len = blacklist.length; i < len; i++) {
      blacklistKey = blacklist[i];
      delete json[blacklistKey];
    }
    return json;
  };

  Model.prototype.defaultJSONBlacklist = function() {
    return ['id', 'created_at', 'updated_at'];
  };

  Model.prototype.createJSONBlacklist = function() {
    return [];
  };

  Model.prototype.updateJSONBlacklist = function() {
    return [];
  };

  Model.prototype.clone = function() {
    return new this.constructor(this.attributes, {
      cached: false
    });
  };

  Model.prototype._parseResultsResponse = function(resp) {
    var id, key;
    if (!resp['results']) {
      return resp;
    }
    if (resp['results'].length) {
      key = resp['results'][0].key;
      id = resp['results'][0].id;
      return resp[key][id];
    } else {
      return {};
    }
  };

  Model.prototype._linkCollection = function(collectionName, models, collectionOptions, field) {
    if (this._associatedCollections == null) {
      this._associatedCollections = {};
    }
    if (!this._associatedCollections[field]) {
      this._associatedCollections[field] = this.storageManager.createNewCollection(collectionName, models, collectionOptions);
      this._associatedCollections[field].on('add', (function(_this) {
        return function() {
          return _this._onAssociatedCollectionChange.call(_this, field, arguments);
        };
      })(this));
      this._associatedCollections[field].on('remove', (function(_this) {
        return function() {
          return _this._onAssociatedCollectionChange.call(_this, field, arguments);
        };
      })(this));
    }
    return this._associatedCollections[field];
  };

  Model.prototype._onAssociatedCollectionChange = function(field, collectionChangeDetails) {
    return this.attributes[this.constructor.associationDetails(field).key] = collectionChangeDetails[1].pluck('id');
  };

  return Model;

})(Backbone.Model);

module.exports = Model;


}).call(this,typeof global !== "undefined" ? global : typeof self !== "undefined" ? self : typeof window !== "undefined" ? window : {})
},{"./storage-manager":10,"./utils":12,"inflection":1}],10:[function(require,module,exports){
(function (global){
var $, Backbone, CollectionLoader, Expectation, ModelLoader, StorageManager, Utils, _StorageManager, inflection, sync;

$ = (typeof window !== "undefined" ? window['$'] : typeof global !== "undefined" ? global['$'] : null);

Backbone = (typeof window !== "undefined" ? window['Backbone'] : typeof global !== "undefined" ? global['Backbone'] : null);

Backbone.$ = $;

inflection = require('inflection');

Utils = require('./utils');

Expectation = require('./expectation');

ModelLoader = require('./loaders/model-loader');

CollectionLoader = require('./loaders/collection-loader');

sync = require('./sync');

_StorageManager = (function() {
  function _StorageManager(options) {
    if (options == null) {
      options = {};
    }
    Backbone.sync = sync;
    this.collections = {};
    this;
  }

  _StorageManager.prototype.storage = function(name) {
    return this.getCollectionDetails(name).storage;
  };

  _StorageManager.prototype.dataUsage = function() {
    var dataType, i, len, ref, sum;
    sum = 0;
    ref = this.collectionNames();
    for (i = 0, len = ref.length; i < len; i++) {
      dataType = ref[i];
      sum += this.storage(dataType).length;
    }
    return sum;
  };

  _StorageManager.prototype.getCollectionDetails = function(name) {
    return this.collections[name] || this.collectionError(name);
  };

  _StorageManager.prototype.collectionNames = function() {
    return _.keys(this.collections);
  };

  _StorageManager.prototype.collectionExists = function(name) {
    return !!this.collections[name];
  };

  _StorageManager.prototype.addCollection = function(name, collectionClass) {
    var collection;
    collection = new collectionClass();
    collection.on('remove', function(model) {
      return model.invalidateCache();
    });
    return this.collections[name] = {
      klass: collectionClass,
      modelKlass: collectionClass.prototype.model,
      storage: collection,
      cache: {}
    };
  };

  _StorageManager.prototype.reset = function() {
    var attributes, name, ref, results;
    ref = this.collections;
    results = [];
    for (name in ref) {
      attributes = ref[name];
      attributes.storage.reset([]);
      results.push(attributes.cache = {});
    }
    return results;
  };

  _StorageManager.prototype.createNewCollection = function(collectionName, models, options) {
    var collection, loaded;
    if (models == null) {
      models = [];
    }
    if (options == null) {
      options = {};
    }
    loaded = options.loaded;
    delete options.loaded;
    collection = new (this.getCollectionDetails(collectionName).klass)(models, options);
    if (loaded) {
      collection.setLoaded(true, {
        trigger: false
      });
    }
    return collection;
  };

  _StorageManager.prototype.createNewModel = function(modelName, options) {
    return new (this.getCollectionDetails(inflection.pluralize(modelName)).modelKlass)(options || {});
  };

  _StorageManager.prototype.loadModel = function(name, id, options) {
    var loader;
    if (options == null) {
      options = {};
    }
    if (!id) {
      return;
    }
    loader = this.loadObject(name, $.extend({}, options, {
      only: id
    }), {
      isCollection: false
    });
    return loader;
  };

  _StorageManager.prototype.loadCollection = function(name, options) {
    var loader;
    if (options == null) {
      options = {};
    }
    loader = this.loadObject(name, options);
    return loader.externalObject;
  };

  _StorageManager.prototype.loadObject = function(name, loadOptions, options) {
    var completeCallback, errorCallback, loader, loaderClass, successCallback;
    if (loadOptions == null) {
      loadOptions = {};
    }
    if (options == null) {
      options = {};
    }
    options = $.extend({}, {
      isCollection: true
    }, options);
    completeCallback = loadOptions.complete;
    successCallback = loadOptions.success;
    errorCallback = loadOptions.error;
    loadOptions = _.omit(loadOptions, 'success', 'error', 'complete');
    loadOptions = $.extend({}, loadOptions, {
      name: name
    });
    if (options.isCollection) {
      loaderClass = CollectionLoader;
    } else {
      loaderClass = ModelLoader;
    }
    this._checkPageSettings(loadOptions);
    loader = new loaderClass({
      storageManager: this
    });
    loader.setup(loadOptions);
    if ((completeCallback != null) && _.isFunction(completeCallback)) {
      loader.always(completeCallback);
    }
    if ((successCallback != null) && _.isFunction(successCallback)) {
      loader.done(successCallback);
    }
    if ((errorCallback != null) && _.isFunction(errorCallback)) {
      loader.fail(errorCallback);
    }
    if (this.expectations != null) {
      this.handleExpectations(loader);
    } else {
      loader.load();
    }
    return loader;
  };

  _StorageManager.prototype.bootstrap = function(name, response, loadOptions) {
    var loader;
    if (loadOptions == null) {
      loadOptions = {};
    }
    loader = new CollectionLoader({
      storageManager: this
    });
    loader.setup($.extend({}, loadOptions, {
      name: name
    }));
    return loader._updateStorageManagerFromResponse(response);
  };

  _StorageManager.prototype.collectionError = function(name) {
    return Utils.throwError("Unknown collection " + name + " in StorageManager. Known collections: " + (_(this.collections).keys().join(", ")));
  };

  _StorageManager.prototype.stub = function(collectionName, options) {
    var expectation;
    if (options == null) {
      options = {};
    }
    if (this.expectations != null) {
      expectation = new Expectation(collectionName, options, this);
      this.expectations.push(expectation);
      return expectation;
    } else {
      throw new Error("You must call #enableExpectations on your instance of Brainstem.StorageManager before you can set expectations.");
    }
  };

  _StorageManager.prototype.stubModel = function(modelName, modelId, options) {
    if (options == null) {
      options = {};
    }
    return this.stub(inflection.pluralize(modelName), $.extend({}, options, {
      only: modelId
    }));
  };

  _StorageManager.prototype.stubImmediate = function(collectionName, options) {
    return this.stub(collectionName, $.extend({}, options, {
      immediate: true
    }));
  };

  _StorageManager.prototype.enableExpectations = function() {
    return this.expectations = [];
  };

  _StorageManager.prototype.disableExpectations = function() {
    return this.expectations = null;
  };

  _StorageManager.prototype.handleExpectations = function(loader) {
    var expectation, i, len, ref;
    ref = this.expectations;
    for (i = 0, len = ref.length; i < len; i++) {
      expectation = ref[i];
      if (expectation.loaderOptionsMatch(loader)) {
        expectation.recordRequest(loader);
        return;
      }
    }
    throw new Error("No expectation matched " + name + " with " + (JSON.stringify(loader.originalOptions)));
  };

  _StorageManager.prototype._checkPageSettings = function(options) {
    if ((options.limit != null) && options.limit !== '' && (options.offset != null) && options.offset !== '') {
      options.perPage = options.page = void 0;
    } else {
      options.limit = options.offset = void 0;
    }
    return this._setDefaultPageSettings(options);
  };

  _StorageManager.prototype._setDefaultPageSettings = function(options) {
    if ((options.limit != null) && (options.offset != null)) {
      if (options.limit < 1) {
        options.limit = 1;
      }
      if (options.offset < 0) {
        return options.offset = 0;
      }
    } else {
      options.perPage = options.perPage || 20;
      if (options.perPage < 1) {
        options.perPage = 1;
      }
      options.page = options.page || 1;
      if (options.page < 1) {
        return options.page = 1;
      }
    }
  };

  return _StorageManager;

})();

StorageManager = (function() {
  var instance;

  function StorageManager() {}

  instance = null;

  StorageManager.get = function() {
    return instance != null ? instance : instance = new _StorageManager(arguments);
  };

  return StorageManager;

})();

module.exports = StorageManager;


}).call(this,typeof global !== "undefined" ? global : typeof self !== "undefined" ? self : typeof window !== "undefined" ? window : {})
},{"./expectation":5,"./loaders/collection-loader":7,"./loaders/model-loader":8,"./sync":11,"./utils":12,"inflection":1}],11:[function(require,module,exports){
(function (global){
var Backbone, Utils, _;

_ = (typeof window !== "undefined" ? window['_'] : typeof global !== "undefined" ? global['_'] : null);

Backbone = (typeof window !== "undefined" ? window['Backbone'] : typeof global !== "undefined" ? global['Backbone'] : null);

Backbone.$ = (typeof window !== "undefined" ? window['$'] : typeof global !== "undefined" ? global['$'] : null);

Utils = require('./utils');

module.exports = function(method, model, options) {
  var beforeSend, data, json, methodMap, params, type, xhr;
  methodMap = {
    create: 'POST',
    update: 'PUT',
    patch: 'PATCH',
    "delete": 'DELETE',
    read: 'GET'
  };
  type = methodMap[method];
  _.defaults(options || (options = {}), {
    emulateHTTP: Backbone.emulateHTTP,
    emulateJSON: Backbone.emulateJSON
  });
  params = {
    type: type,
    dataType: 'json'
  };
  if (!options.url) {
    params.url = _.result(model, 'url') || urlError();
  }
  if ((options.data == null) && model && (method === 'create' || method === 'update' || method === 'patch')) {
    params.contentType = 'application/json';
    data = options.attrs || {};
    if (model.toServerJSON != null) {
      json = model.toServerJSON(method, options);
    } else {
      json = model.toJSON(options);
    }
    if (model.paramRoot) {
      data[model.paramRoot] = json;
    } else {
      data = json;
    }
    data.include = Utils.extractArray("include", options).join(",");
    data.filters = Utils.extractArray("filters", options).join(",");
    _.extend(data, options.params || {});
    params.data = JSON.stringify(data);
  }
  if (options.emulateJSON) {
    params.contentType = 'application/x-www-form-urlencoded';
    params.data = params.data ? {
      model: params.data
    } : {};
  }
  if (options.emulateHTTP && (type === 'PUT' || type === 'DELETE' || type === 'PATCH')) {
    params.type = 'POST';
    if (options.emulateJSON) {
      params.data._method = type;
    }
    beforeSend = options.beforeSend;
    options.beforeSend = function(xhr) {
      xhr.setRequestHeader('X-HTTP-Method-Override', type);
      if (beforeSend) {
        return beforeSend.apply(this, arguments);
      }
    };
  }
  if (params.type === 'DELETE') {
    params.data = null;
  }
  if (params.type !== 'GET' && !options.emulateJSON) {
    params.processData = false;
  }
  if (params.type === 'PATCH' && window.ActiveXObject && !(window.external && window.external.msActiveXFilteringEnabled)) {
    params.xhr = function() {
      return new ActiveXObject("Microsoft.XMLHTTP");
    };
  }
  xhr = options.xhr = Backbone.ajax(_.extend(params, options));
  model.trigger('request', model, xhr, options);
  return xhr;
};


}).call(this,typeof global !== "undefined" ? global : typeof self !== "undefined" ? self : typeof window !== "undefined" ? window : {})
},{"./utils":12}],12:[function(require,module,exports){
(function (global){
var Backbone, Error, Utils, _,
  slice = [].slice;

_ = (typeof window !== "undefined" ? window['_'] : typeof global !== "undefined" ? global['_'] : null);

Backbone = (typeof window !== "undefined" ? window['Backbone'] : typeof global !== "undefined" ? global['Backbone'] : null);

Backbone.$ = (typeof window !== "undefined" ? window['$'] : typeof global !== "undefined" ? global['$'] : null);

Error = require('./error');

Utils = (function() {
  function Utils() {}

  Utils.warn = function() {
    var args;
    args = 1 <= arguments.length ? slice.call(arguments, 0) : [];
    return typeof console !== "undefined" && console !== null ? console.log.apply(console, ["Error:"].concat(slice.call(args))) : void 0;
  };

  Utils.throwError = function(message) {
    var fragment;
    message = "" + message;
    fragment = (function() {
      var ref;
      try {
        return (ref = Backbone.history) != null ? ref.getFragment() : void 0;
      } catch (undefined) {}
    })();
    if (fragment) {
      message += ", fragment: " + fragment;
    }
    throw new Error(message);
  };

  Utils.matches = function(obj1, obj2) {
    var obj1Keys, obj2Keys;
    if (this.empty(obj1) && this.empty(obj2)) {
      return true;
    } else if (obj1 instanceof Array && obj2 instanceof Array) {
      return obj1.length === obj2.length && _.every(obj1, (function(_this) {
        return function(value, index) {
          return _this.matches(value, obj2[index]);
        };
      })(this));
    } else if (obj1 instanceof Object && obj2 instanceof Object) {
      obj1Keys = _(obj1).keys();
      obj2Keys = _(obj2).keys();
      return obj1Keys.length === obj2Keys.length && _.every(obj1Keys, (function(_this) {
        return function(key) {
          return _this.matches(obj1[key], obj2[key]);
        };
      })(this));
    } else {
      return String(obj1) === String(obj2);
    }
  };

  Utils.empty = function(thing) {
    if (thing === null || thing === void 0 || thing === "") {
      true;
    }
    if (thing instanceof Array) {
      return thing.length === 0 || thing.length === 1 && this.empty(thing[0]);
    } else if (thing instanceof Object) {
      return _.keys(thing).length === 0;
    } else {
      return false;
    }
  };

  Utils.extractArray = function(option, options) {
    var result;
    result = options[option];
    if (!(result instanceof Array)) {
      result = [result];
    }
    return _.compact(result);
  };

  Utils.wrapObjects = function(array) {
    var output;
    output = [];
    _(array).each((function(_this) {
      return function(elem) {
        var key, o, results, value;
        if (elem.constructor === Object) {
          results = [];
          for (key in elem) {
            value = elem[key];
            o = {};
            o[key] = _this.wrapObjects(value instanceof Array ? value : [value]);
            results.push(output.push(o));
          }
          return results;
        } else {
          o = {};
          o[elem] = [];
          return output.push(o);
        }
      };
    })(this));
    return output;
  };

  Utils.wrapError = function(collection, options) {
    var error;
    error = options.error;
    return options.error = function(response) {
      if (error) {
        error(collection, response, options);
      }
      return collection.trigger('error', collection, response, options);
    };
  };

  return Utils;

})();

module.exports = Utils;


}).call(this,typeof global !== "undefined" ? global : typeof self !== "undefined" ? self : typeof window !== "undefined" ? window : {})
},{"./error":4}]},{},[2])(2)
});