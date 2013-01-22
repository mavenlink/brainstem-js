#= require ./attachment

class App.Models.GoogleDocument extends App.Models.Attachment
  getFilesizeDisplayText: =>
    ""

  getIconClassName: =>
    docTypes = ['document', 'spreadsheet', 'presentation', 'drawing', 'item', 'file']
    docType = @get('type').substr(16)
    docType = "other" unless docType in docTypes
    "google-doc-" + docType

class App.Collections.GoogleDocuments extends Mavenlink.Collection
  model: App.Models.GoogleDocument