require_relative '../spec_helper'
require_relative '../../lib/affilinet'

module AffilinetAPI
  describe API::WebService, :vcr do
    describe 'BASE_URL' do
      it 'should return the development URL in specs' do
        expect(AffilinetAPI::API::BASE_URL).to start_with 'https://developer-api'
      end
    end

    describe '#initialize' do
      it 'works without any exception' do
        expect do
          API::WebService.new(API::SERVICES[:statistics],
                              ENV['AFFILINET_USER'],
                              ENV['AFFILINET_PUBLISHER_PASSWORD'])
        end.not_to raise_error
      end
    end
  end
end
