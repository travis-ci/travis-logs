require 'travis/logs/services/append'

module Travis
  module Logs
    class  Handler
      class Log < Handler
        def handle
          # info "#{Thread.current.object_id} handling log update for job #{data['id']}" unless Travis.env == 'production'
          Travis.run_service(:logs_append, data: data)
          # info "#{Thread.current.object_id} done handling log update for job #{data['id']}: #{data['log'].to_s.bytesize} bytes" # unless Travis.env == 'production'
        end
        instrument :handle
        new_relic :handle

        def data
          payload['data']
        end

        # Travis::Logs::Instrument::Handler::Log.attach_to(self)
      end
    end
  end
end
