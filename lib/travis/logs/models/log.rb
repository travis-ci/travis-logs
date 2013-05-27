require 'active_record'

class Log < ActiveRecord::Base
  validates :job_id, presence: true, numericality: { greater_than: 0 }
end