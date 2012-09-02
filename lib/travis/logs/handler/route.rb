require 'base64'

module Travis
  class Logs
    class  Handler
      class Route < Handler
        def handle
          publisher.publish(encode(payload))
        end
        instrument :handle
        new_relic :handle

        def publisher
          debug "routing job-#{job_id} to: reporting.jobs.logs.#{shard}"
          Travis::Amqp::Publisher.jobs("logs.#{shard}")
        end

        def shard
          job_id % Travis.config.logs.shards
        end

        def job_id
          payload['data']['id'].to_i
        end

        # working around an issue with bad bytes and json on jruby 1.7
        # see https://github.com/flori/json/issues/138
        def encode(payload)
          payload['data']['log'] = Base64.encode64(payload['data']['log'])
          payload
        end

        # Travis::Logs::Instrument::Handler::Log.attach_to(self)
      end
    end
  end
end
