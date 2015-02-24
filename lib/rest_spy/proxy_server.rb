require 'faraday'
module RestSpy
  module ProxyServer
    extend self

    def execute_remote_request(original_request, redirect_url, environment)
      headers = extract_relevant_headers(environment)
      composed_url = URI::join(redirect_url, original_request.fullpath).to_s

      if original_request.get?
        http_client.get(composed_url, headers)
      elsif original_request.post?
        http_client.post(composed_url, headers, original_request.body)
      else
        raise "#{original_request.request_method} requests are not supported."
      end
    end

    def extract_relevant_headers(environment)
      Hash[environment
               .select { |k, _| k.start_with?("HTTP_") && k != "HTTP_HOST"}
               .map { |k, v| [k.sub(/^HTTP_/, ''), v] }]
    end

    def http_client
      HttpClient.new
    end

    class HttpClient
      def get(url, headers)
        Faraday.new.get url do |req|
          req.headers = headers
        end
      end

      def post(url, headers, body)
        Faraday.new.post url do |req|
          req.headers = headers
          req.body = body
        end
      end
    end
  end
end