Collection = require '../../src/collection'

User = require './user'


class Users extends Collection
  model: User
  url: "/api/users"


module.exports = Users
