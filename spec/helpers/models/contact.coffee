class App.Models.Contact extends Brainstem.Model
  paramRoot: 'contact'

  defaults:
    id: null
    interaction_count: 0
    consultant_occurrences: 0
    client_occurrences: 0

  @associations:
    connection: "users"

class App.Collections.Contacts extends Brainstem.Collection
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