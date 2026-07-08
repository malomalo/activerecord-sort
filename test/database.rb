class SunstoneRecord < ActiveRecord::Base
  self.abstract_class = true
end

class Point < SunstoneRecord
  belongs_to :line
end

class Line < SunstoneRecord
  has_many :points
end

SunstoneRecord.establish_connection({
  adapter: 'sunstone',
  url: 'http://example.com'
})
