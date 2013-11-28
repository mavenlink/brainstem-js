class App.Models.User extends Brainstem.Model
  brainstemKey: "users"
  paramRoot: 'user'
  urlRoot: "/api/users"

class App.Collections.Users extends Brainstem.Collection
  model: App.Models.User
  url: "/api/users"
