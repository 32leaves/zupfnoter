#require 'promise'

module Bowser
  module ServiceWorker
    class Promise
      attr_reader :value, :failure

      def initialize &block
        @native = `new Promise(function(resolve, reject) {
          #{@resolve = `resolve`};
          #{@reject = `reject`};
          #{block.call(self) if block_given?};
        })`
      end

      def self.from_native promise
        p = allocate
        p.instance_exec { @native = promise }
        p
      end

      def self.all promises
        from_native `Promise.all(#{promises.map(&:to_n)})`
      end

      def self.race promises
        from_native `Promise.race(#{promises.map(&:to_n)})`
      end

      def self.reject reason
        new.reject reason
      end

      def self.resolve value
        new.resolve value
      end

      def then &block
        Promise.from_native `#@native.then(block)`
      end

      def fail &block
        Promise.from_native `#@native.catch(block)`
      end

      def always &block
        Promise.from_native `#@native.then(block).fail(block)`
      end

      def resolve value
        return self if resolved?
        if rejected?
          `console.warn(#{self}, #{"tried to resolve, already #{resolved? ? 'resolved' : 'rejected'} with"}, #{@value || @failure})`
        end

        @value = value
        @resolve.call value
        self
      end

      def reject failure
        return self if rejected?
        if resolved?
          `console.warn(#{self}, #{"tried to reject, already #{resolved? ? 'resolved' : 'rejected'} with"}, #{@value || @failure})`
        end

        @failure = failure
        @reject.call failure
        self
      end

      def realized?
        resolved? || rejected?
      end

      def resolved?
        !value.nil?
      end

      def rejected?
        !failure.nil?
      end

      def to_n
        @native
      end

      %x{
        Opal.defn(self, 'then', function(callback) {
          var self = this;
          #{self.then(&`callback`)};
        });
        Opal.defn(self, 'catch', function(callback) {
          var self = this;
          #{self.fail(&`callback`)};
        });
      }
    end
  end
end


module Opal
  module DropboxJs


    # this is a dummy client to register before login
    class NilClient
      attr_accessor :root_in_dropbox, :app_name

      def authenticate()
        raise I18n.t("not logged in to dropbox")
      end
    end

    # This class wraps the dropbox-js client
    # http://coffeedoc.info/github/dropbox/dropbox-js/master/class_index.html
    # all methods yield a promise (see http://opalrb.org/blog/2014/05/07/promises-in-opal/)
    class Client
      attr_accessor :root_in_dropbox, :app_name, :app_id


      # @param [String] key - the Dropbox API key
      def initialize(key)
        @errorlogger = lambda { |error| $log.error(error) }

        @root = `new Dropbox({clientId: #{key}});`

        # %x{
        #    self.root.onError.addListener(function(error) {
        #                            self.errorlogger(error)
        #    });
        # }
      end

      def getAccessToken(iblock)
        %x{
            parseQueryString = function(str) {
                  var ret = Object.create(null);

                  if (typeof str !== 'string') {
                    return ret;
                  }

                  str = str.trim().replace(/^(\?|#|&)/, '');

                  if (!str) {
                    return ret;
                  }

                  str.split('&').forEach(function (param) {
                    var parts = param.replace(/\+/g, ' ').split('=');
                    // Firefox (pre 40) decodes `%3D` to `=`
                    // https://github.com/sindresorhus/query-string/pull/37
                    var key = parts.shift();
                    var val = parts.length > 0 ? parts.join('=') : undefined;

                    key = decodeURIComponent(key);

                    // missing `=` should be `null`:
                    // http://w3.org/TR/2012/WD-url-20120524/#collect-url-parameters
                    val = val === undefined ? null : decodeURIComponent(val);

                    if (ret[key] === undefined) {
                      ret[key] = val;
                    } else if (Array.isArray(ret[key])) {
                      ret[key].push(val);
                    } else {
                      ret[key] = [ret[key], val];
                    }
                  });
                  return ret;
                }


            access_token = localStorage.getItem('dbx_token');  // try to ge an accesstoken from previous session
            if (!access_token) {
                dropbox_answers = parseQueryString(window.location.hash);   // see if access token is provided by url as part of the authentification process
                access_token = dropbox_answers.access_token;
                if (access_token) {
                    localStorage.setItem('dbx_token', access_token);
                    #{iblock.call(nil, true)}
                    window.location.href = #{Controller::get_uri[:origin]}; // this is just to remove the access token from the adress bar
                 }
                else if (dropbox_answers.error)
                 {
                  #{iblock.call(%x{errror}, nil)}
                 }
                else
                 {
                  var authUrl = #{@root}.getAuthenticationUrl(#{Controller::get_uri[:origin]+"/"});
                  #{iblock.call(nil, true)}
                  window.location.href=authUrl;
                 }
            }
           else
            {
             #{@root} = new Dropbox({accessToken: access_token})
             #{iblock.call(nil, true)}
            }
        }
      end

      def logout

      end

      # this method supports to execute a block in a promise
      #
      # with_promise() do |iblock|
      #     the payload code handle argument
      #     iblock = the block provided to the underlying API.
      #              its signature is derived from the the underlying library.
      #              in this case it is defined by the callbacks of drobox-js which has two paramteres (error, data)
      # end
      #
      # @yieldparam [Lambda] block payload the block with the job to do
      # @return [Promise]
      #
      def with_promise(&block)
        Bowser::ServiceWorker::Promise.new.tap do |promise|
          block.call(lambda { |error, data|
            if error
              # todo: don't know if this is generic enough. it assumes that error is a dedicated structure.
              errormessage = Native(error).error rescue "unspecified error from Dropbox API"
              promise.reject(errormessage)
            else
              promise.resolve(data)
            end
          }
          )
        end
      end

      # this method supports to invoke the dropbox_chooser
      #
      # with_promise() do |iblock|
      #     the payload code handle argument
      #     iblock = the block provided to the underlying API.
      #              its signature is derived from the the underlying library.
      #              in this case it is defined by the callbacks of
      #              dropbox chooser which has one parameter (and no error handling)
      #
      # @yieldparam [Lambda] block payload the block with the job to do
      # @return [Promise]
      #
      def with_promise_chooser(&block)
        Promise.new.tap do |promise|
          block.call(lambda { |data|
            if false
              promise.reject(Native(error)[:response].error)
            else
              promise.resolve(Native(data))
            end
          }
          )
        end
      end

      # this is like with_promie, but
      # does a bunch of retries
      def with_promise_retry(info= "", retries = 2, &block)
        Promise.new.tap do |promise|
          remaining = retries
          handler   = lambda { |error, data|
            if error
              remaining -= 1
              if remaining >= 0
                $log.info("#{remaining} remaining retries #{info}")
                block.call(handler)
              else
                $log.error(I18n.t("Error from Dropbox with failed retries"))
                promise.reject("Repeated Error from Dropobox")
              end
            else
              $log.info("successs #{info}")
              promise.resolve(data)
            end
          }
          block.call(handler)
        end
      end


      # authenticate on dropbox
      # @return [Promise]
      def authenticate()
        with_promise() do |iblock|
          #  %x(#@root.authenticate(#{iblock}))
          getAccessToken(iblock)
        end
      end


      # get information about the dropbox account
      # @return [Promise]
      def get_account_info()
        with_promise() do |iblock|
          %x{#@root.getAccountInfo(#{iblock})}
        end
      end

      # write a file to dropbox

      # @param [String] filename of the file to be written to
      # @param [String] data data to be written to the file
      # @return [Promise]

      def write_file(filename, data)
        $log.debug("waiting")
        with_promise_retry(filename, 2) do |iblock|
          %x{#@root.writeFile(#{filename}, #{data}, #{iblock})}
        end
      end


      # @param [String] filename name of the file to be read
      # @return [Promise]

      def read_file(filename)
        with_promise() do |iblock|
          %x{#@root.readFile(#{filename}, #{iblock})}
        end
      end


      # @param [String] dirname - name of the directory to be read
      # @return [Promise]

      def read_dir(dirname = "/")
        with_promise() do |iblock|
          %x{
             #{@root}.filesListFolder({path: #{dirname}})
                .then(function (response) {
                    #{iblock}(nil, response.entries.map(function(i){return i.name}))
                })
                .catch(function (error) {
                    #{iblock}(error, nil)
                });
          }
        end
      end

      # @param [String] dirname - name of the directory to be read
      # @return [Promise]

      def read_dirxx(dirname = "/")
        a = %x{#{@root}.filesListFolder({path: #{dirname}})}
        Bowser::ServiceWorker::Promise.from_native(a).then do |value|
          Bowser::ServiceWorker::Promise.new.tap do |promise|
            begin
              result = Native(value)[:entries].map { |i| i.name }
              promise.resolve(result)
            rescue Exception => error
              promise.reject(error.message)
            end
          end
        end
      end


      def choose_file(options)

        with_promise_chooser() do |iblock|
          %x{
              dropbox_options = {

                  // Required. Called when a user selects an item in the Chooser.
                      success: #{iblock},

                  // Optional. Called when the user closes the dialog without selecting a file
                  // and does not include any parameters.
                          cancel: function() {

                                  },

                       linkType: "direct", // or "direct"

                  // Optional. This is a list of file extensions. If specified, the user will
                  // only be able to select files with these extensions. You may also specify
                  // file types, such as "video" or "images" in the list. For more information,
                  // see File types below. By default, all extensions are allowed.
                      extensions: ['.abc'],
                  };

                  Dropbox.choose(dropbox_options);
          }
        end
      end


    end

  end
end