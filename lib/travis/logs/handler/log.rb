# require 'base64'

module Travis
  class Logs
    class  Handler
      class Log < Handler
        def handle
          debug "handling log update for job #{data['id']}"
          ::Job::Test.append_log!(data['id'], data['log'])
        end
        instrument :handle
        new_relic :handle

        def data
          # @data ||= decode(payload['data'])
          payload['data']
        end

        # # working around an issue with bad bytes and json on jruby 1.7
        # # see https://github.com/flori/json/issues/138
        # def decode(data)
        #   data['log'] = Base64.decode64(data['log'])
        #   data
        # end

        # Travis::Logs::Instrument::Handler::Log.attach_to(self)
      end
    end
  end
end
