require 'savon'
require 'active_support/all'
require 'dotenv'
Dotenv.load("#{ENV['AFFILINET_ENV']}.env", '.env')

module AffilinetAPI
  class API
    BASE_URL = "https://#{ENV['AFFILINET_HOST_PREFIX']}api.affili.net".freeze
    # create a new webservice for each wsdl
    SERVICES = {
      creative: '/V2.0/PublisherCreative.svc?wsdl',
      product: '/V2.0/ProductServices.svc?wsdl',
      inbox: '/V2.0/PublisherInbox.svc?wsdl',
      account: '/V2.0/AccountService.svc?wsdl',
      statistics: '/V2.0/PublisherStatistics.svc?wsdl',
      program_list: '/V2.0/PublisherProgram.svc?wsdl'
    }.freeze

    LOGON_SERVICE = '/V2.0/Logon.svc?wsdl'.freeze

    SERVICES.each do |key, wsdl|
      define_method(key) do
        @services ||= {}
        @services[wsdl] ||= AffilinetAPI::API::WebService.new(wsdl, @user, @password)
      end
    end

    # set the base_url and credentials
    #
    def initialize(user, password, options = {})
      @user = user
      @password = password
    end

    class WebService
      def initialize(wsdl, user, password)
        @wsdl = wsdl
        @user = user
        @password = password
      end

      # checks against the wsdl if method is supported and raises an error if not
      #
      # TODO we don't want ...RequestMessage for the creative service
      # consequently those services don't work
      def method_missing(method, *args)
        return super unless operations_include?(method)

        op = operation(method)
        camelized_name = method.to_s.camelize
        op.body = if method == :get_payments || method == :search_creatives
                    {
                      "#{camelized_name}Request" => {
                        'CredentialToken' => token
                      }.merge(args.first)
                    }
                  else
                    {
                      "#{camelized_name}Request" => {
                        'CredentialToken' => token,
                        "#{camelized_name}RequestMessage" => args.first
                      }
                    }
                  end
        res = op.call
        Hashie::Mash.new res.body.values.first
      end

      protected

      # only return a new driver if no one exists already
      #
      def driver
        @driver ||= Savon.new(BASE_URL + @wsdl)
      end

      def logon_driver
        @logon_driver ||= Savon.new(BASE_URL + LOGON_SERVICE)
      end

      # returns actual token or a new one if expired
      #
      def token
        return @token if @token && @created > 20.minutes.ago

        @created = Time.now
        @token = fresh_token
      end

      def fresh_token
        operation = logon_driver.operation('Authentication', 'DefaultEndpointLogon', 'Logon')
        operation.body = logon_body
        response = operation.call
        response.body[:credential_token]
      end

      def logon_body
        {
          LogonRequestMsg: {
            'Username' => @user,
            'Password' => @password,
            'WebServiceType' => 'Publisher',
          }
        }.tap do |body|
          if ENV['AFFILINET_SANDBOX_PUBLISHER_ID'].present?
            body['DeveloperSettings'] = {
              SandboxPublisherID: ENV['AFFILINET_SANDBOX_PUBLISHER_ID']
            }
          end
        end
      end

      def operations_include?(method)
        operations.include? api_method(method)
      end

      def operations
        driver.operations(service, port)
      end

      def operation(method)
        driver.operation service, port, api_method(method)
      end

      def services
        driver.services
      end

      def service
        services.keys.first
      end

      def port
        port = services.values.first[:ports].keys.first
      end

      # handles the special name case of getSubIDStatistics
      #
      def api_method(method)
        method.to_s.camelize.sub 'GetSubIdStatistics', 'GetSubIDStatistics'
      end
    end # WebService
  end
end
