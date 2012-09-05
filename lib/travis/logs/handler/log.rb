module Travis
  class Logs
    class  Handler
      class Log < Handler
        def handle
          info "handling log update for job #{data['id']}"
          breakz!
          ::Job::Test.append_log!(data['id'], data['log'])
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
