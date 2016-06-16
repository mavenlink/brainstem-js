Model = require '../../../src/model'


class User extends Model
  brainstemKey: "users"
  paramRoot: 'user'
  urlRoot: "/api/users"


module.exports = User
