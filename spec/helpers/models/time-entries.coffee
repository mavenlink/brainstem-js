Collection = require '../../../src/collection'

TimeEntry = require './time-entry'


class TimeEntries extends Collection
  model: TimeEntry
  url: '/api/time_entries'


module.exports = TimeEntries
