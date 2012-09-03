$: << 'lib'

require 'travis'
require 'bunny'
require 'consumer'

b = Travis::Amqp.connection
b.qos

consumer = Travis::Amqp::Consumer.new('jobs')
consumer.subscribe(:ack => true) do |msg, payload|
  p payload
  # p msg
  msg.ack
end

# q = b.queue('jobs')
#
# q.subscribe(:ack => true) do |msg|
#   msg_cnt = q.message_count
#   p msg
#   q.ack
#
#   # if msg_cnt < 1
#   #   q.unsubscribe
#   #   q.ack
#   #   break
#   # end
# end
