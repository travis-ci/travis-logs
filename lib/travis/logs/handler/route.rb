require 'string_cleaner'

module Travis
  class Logs
    class  Handler
      class Route < Handler
        def handle
          publisher.publish(payload)
        end
        instrument :handle
        new_relic :handle

        def publisher
          info "routing job-#{job_id} to: reporting.jobs.logs.#{shard}" unless Travis.env == 'production'
          Travis::Amqp::Publisher.jobs("logs.#{shard}")
        end

        def shard
          job_id % Travis.config.logs.shards
        end

        def job_id
          payload['data']['id'].to_i
        end

        # Travis::Logs::Instrument::Handler::Log.attach_to(self)
      end
    end
  end
end
