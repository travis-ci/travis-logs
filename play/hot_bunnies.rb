require 'travis'

publisher = Travis::Amqp::Publisher.new('jobs')
3.times do
  p publisher.publish('fooo!')
end
