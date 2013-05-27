require 'active_record'

class LogPart < ActiveRecord::Base
  validates :log_id, presence: true, numericality: { greater_than: 0 }
end