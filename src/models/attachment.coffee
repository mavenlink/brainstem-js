class App.Models.Attachment extends Mavenlink.Model
  # note, this is just for inheritence, you shouldn't be relying on these.

  getFilesizeDisplayText: =>
    ""

  getIconClassName: =>
    "icon-type-other"

  deleted: =>
    @get 'deleted_at'