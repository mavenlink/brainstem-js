#= require ./attachment

class App.Models.GoogleDocument extends App.Models.Attachment

class App.Collections.GoogleDocuments extends Brainstem.Collection
  model: App.Models.GoogleDocument