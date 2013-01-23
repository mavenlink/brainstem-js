class App.Models.User extends Mavenlink.Model
  paramRoot: 'user'

  defaults:
    id: null
    full_name: null
    photo_path: null

  getDisplayName: =>
    if (@get('id') == base.currentUserId()) then 'You' else @get('full_name')

class App.Collections.Users extends Mavenlink.Collection
  model: App.Models.User
  url: "/api/users"
