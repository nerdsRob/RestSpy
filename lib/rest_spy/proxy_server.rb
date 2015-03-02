require 'faraday'
require 'faraday_middleware'
require 'json'
require_relative 'response_rewriter'

module RestSpy
  module ProxyServer
    extend self

    def execute_remote_request(original_request, redirect_url, environment, rewrites)
      headers = extract_relevant_headers(environment)
      composed_url = URI::join(redirect_url, original_request.fullpath).to_s

      http_client = http_client(rewrites)

      if original_request.get?
        http_client.get(composed_url, headers)
      elsif original_request.post?
        http_client.post(composed_url, headers, get_body(original_request))
      elsif original_request.put?
        http_client.put(composed_url, headers, get_body(original_request))
      elsif original_request.delete?
        http_client.delete(composed_url, headers)
      else
        raise "#{original_request.request_method} requests are not supported."
      end
    end

    def extract_relevant_headers(environment)
      Hash[environment
               .select { |k, _| k.start_with?("HTTP_") && k != "HTTP_HOST"}
               .map { |k, v| [k.sub(/^HTTP_/, ''), v] }]
    end

    def get_body(request)
      #TODO: Investigate better way to extract the body (support different type of data)
      JSON.parse(request.body.read)
    rescue JSON::ParserError
      request.body.read
    end

    def http_client(rewrites)
      HttpClient.new(rewrites)
    end

    class HttpClient
      def initialize(rewrites=[])
        @connection = Faraday.new do |conn|
          conn.request :multipart
          conn.request :url_encoded
          conn.use RestSpy::ResponseRewriter, rewrites: rewrites
          conn.adapter :net_http
        end
      end

      def get(url, headers)
        connection.get url do |req|
          req.headers = headers
        end
      end

      def post(url, headers, body)
        connection.post url do |req|
          req.headers = headers
          req.body = body
        end
      end

      def put(url, headers, body)
        connection.put url do |req|
          req.headers = headers
          req.body = body
        end
      end

      def delete(url, headers)
        connection.delete url do |req|
          req.headers = headers
        end
      end

      private
      attr_reader :connection
    end
  end
end