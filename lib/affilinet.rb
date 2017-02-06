require 'savon'
require 'active_support/all'
require 'dotenv'
Dotenv.load("#{ENV['AFFILINET_ENV']}.env", '.env')

module AffilinetAPI
  class API
    BASE_URL = "https://#{ENV['AFFILINET_HOST_PREFIX']}api.affili.net".freeze
    API_VERSION = 'V2.0'
    # create a new webservice for each wsdl
    SERVICES = {
      creative: :PublisherCreative,
      product: :ProductServices,
      inbox: :PublisherInbox,
      account: :AccountService,
      statistics: :PublisherStatistics,
      program_list: :PublisherProgram
    }.freeze

    LOGON_SERVICE = "/#{API_VERSION}/Logon.svc?wsdl".freeze

    SERVICES.each do |key, endpoint|
      define_method(key) do
        @services ||= {}
        @services[endpoint] ||= AffilinetAPI::API::WebService.new(endpoint, @user, @password)
      end
    end

    # set the base_url and credentials
    #
    def initialize(user, password, options = {})
      @user = user
      @password = password
    end

    class WebService
      def initialize(endpoint, user, password)
        @endpoint = endpoint
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

        result_hash = Hashie::Mash.new(res.body.values.first)
        flatten_result method.to_s, parse_result(result_hash)
      end

      protected

      # returns the subject the soap method handles
      def soap_subject(method_name)
        method_name.sub(/^(get|create|update|send|set|delete)_/, '').singularize
      end

      # returns variations that may appear in a SOAP result
      def soap_subject_variations(method_name)
        singularized_name = soap_subject method_name
        pluralized_name = singularized_name.pluralize

        [
          singularized_name,
          "#{singularized_name}_record",
          "#{singularized_name}_records",
          pluralized_name,
          "#{pluralized_name}_record",
          "#{pluralized_name}_records"
        ]
      end

      def flatten_result(method_name, result_hash)
        keys = result_hash.keys.select { |k| !k.start_with?('@xmlns') }
        return result_hash if keys.count != 1

        key_variations = soap_subject_variations method_name

        key = (keys & key_variations).first

        key.nil? ? result_hash : flatten_result(method_name, result_hash[key])
      end

      def parse_result(result_hash)
        return result_hash if result_hash['faultstring'].nil?

        missing_var = result_hash['faultstring'].match(/Expecting element '(?<var>[^']+)'/)
        return result_hash unless missing_var

        raise ArgumentError, "Parameter #{missing_var[:var].inspect} is required but wasn't given."
      end

      # only return a new driver if no one exists already
      #
      def driver
        @driver ||= Savon.new(BASE_URL + "/#{API_VERSION}/#{@endpoint}.svc?wsdl")
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
