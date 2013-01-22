class App.Models.Contact extends Mavenlink.Model
  paramRoot: 'contact'

  defaults:
    id: null
    interaction_count: 0
    consultant_occurrences: 0
    client_occurrences: 0

  @associations:
    connection: "users"

  matchesSearch: (string) =>
    for text in [@get("connection").get('full_name'), @get("connection").get('email_address')]
      if text && text.toLowerCase().replace(/[,:]/g, '').indexOf(string.toLowerCase().replace(/[,:]/g, '')) > -1
        return true

  getDefaultRole: =>
    if @get('client_occurrences') > @get('consultant_occurrences')
      'buyer'
    else
      'maven'

class App.Collections.Contacts extends Mavenlink.Collection
  model: App.Models.Contact
  url: "/api/contacts"

  @getComparator: (field) ->
    if field == "interaction_score"
      return (a, b) ->
        result = a.get("interaction_count") - b.get("interaction_count")

        if result == 0
          result = a.get("updated_at") - b.get("updated_at")

        if result == 0
          result = a.id - b.id

        return result
    else
      super