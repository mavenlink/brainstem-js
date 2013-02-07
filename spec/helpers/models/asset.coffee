require 'models/attachment'

class App.Models.Asset extends App.Models.Attachment

class App.Collections.Assets extends Brainstem.Collection
  model: App.Models.Asset
  url  : '/api/assets'
