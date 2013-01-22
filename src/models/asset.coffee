require 'models/attachment'

class App.Models.Asset extends App.Models.Attachment
  getFilesizeDisplayText: =>
    Utils.filesizeInWords(@.get('filesize'), 2)

  getIconClassName: =>
    Utils.getCssClassForExtension(@getExtension())

  getExtension: =>
    Utils.getFilenameExtension(@get("filename"))


class App.Collections.Assets extends Mavenlink.Collection
  model: App.Models.Asset
  url  : '/api/assets'
