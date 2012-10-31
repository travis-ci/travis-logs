module Travis
  class Logs
    class  Handler
      class Log < Handler
        def handle
          info "#{Thread.current.object_id} handling log update for job #{data['id']}" unless Travis.env == 'production'
          ::Job::Test.append_log!(data['id'], data['log'])
          info "#{Thread.current.object_id} done handling log update for job #{data['id']}" unless Travis.env == 'production'
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
