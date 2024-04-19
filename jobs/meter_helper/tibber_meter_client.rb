require "graphql/client"
require "graphql/client/http"

class TibberMeter

  attr_reader :meter_count

  def initialize
    print "TibberMeter initialized \n"
  end

  def get_meter_count()
    return @meter_count
  end

  def get_meter_count_from_tibber()
    return nil
  end

  def get_meter_count_from_tibber()
    api_url = 'https://api.tibber.com/v1-beta/gql'
    access_token = ENV['TIBBER_ACCESS_TOKEN']
    http = GraphQL::Client::HTTP.new(api_url) do
      def headers(context)
        {
            "Authorization" => "Bearer #{@access_token}",
            "User-Agent" => "TibberMeter/1.0"
        }
      end
    end

    schema = GraphQL::Client.load_schema(http)
    client = GraphQL::Client.new(schema: schema, execute: http)

    puts "." * 10
    puts "Client: #{client} \n"

    client.parse <<-'GRAPHQL'
    query {
      viewer {
        homes{
            id
        }
      }
    }
    GRAPHQL


    response = client.query(Query::Homes)

    puts "Response #{response.data.homes}"
    return nil
  end
end