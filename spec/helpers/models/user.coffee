class App.Models.User extends Brainstem.Model
  paramRoot: 'user'

class App.Collections.Users extends Brainstem.Collection
  model: App.Models.User
  url: "/api/users"
