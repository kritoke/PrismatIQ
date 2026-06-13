require "http/client"
require "uri"
require "socket"
require "openssl"
require "./utils/ip_validator"
require "./version"

module PrismatIQ
  # Dedicated HTTP fetcher with SSRF protection, rate limiting, and streaming.
  #
  # Extracted from ThemeExtractor to satisfy Single Responsibility Principle:
  # ThemeExtractor orchestrates theme extraction; URLFetcher handles HTTP concerns.
  class URLFetcher
    def initialize(@config : Config = Config.default)
    end

    # Fetches content from a URI with SSRF validation, rate limiting, and size limits.
    # Returns the response body as a Slice(UInt8), or nil on any failure.
    def fetch(uri : URI, options : ThemeOptions) : Slice(UInt8)?
      host = uri.host
      return unless host
      return unless {"http", "https"}.includes?(uri.scheme)

      unless @config.rate_limit_allow?
        @config.log_debug "fetch_url: rate limited, please retry later"
        return
      end

      port = uri.port || (uri.scheme == "https" ? 443 : 80)
      use_tls = uri.scheme == "https"

      validated_ip = resolve_and_validate_host(host)
      return if validated_ip == :blocked

      client : HTTP::Client? = nil
      begin
        client = if validated_ip.is_a?(Socket::IPAddress)
                   connect_to_ip(validated_ip.as(Socket::IPAddress), host, port, use_tls)
                 else
                   HTTP::Client.new(host, port, tls: use_tls)
                 end

        client.read_timeout = options.http_timeout.seconds
        client.connect_timeout = options.http_timeout.seconds

        default_port = use_tls ? 443 : 80
        host_value = port == default_port ? host : "#{host}:#{port}"

        headers = HTTP::Headers{
          "User-Agent" => "PrismatIQ/#{Version::VERSION}",
          "Accept"     => "image/*,*/*;q=0.8",
          "Host"       => host_value,
        }

        response = client.get(uri.request_target, headers: headers)
        return unless response_valid?(response, options)

        stream_body(response.body_io, options.max_file_size)
      rescue ex : IO::Error | OpenSSL::Error | ArgumentError
        @config.log_debug "fetch_url: exception #{ex.class.name}: #{ex.message}"
        nil
      ensure
        client.try(&.close)
      end
    end

    private def resolve_and_validate_host(host : String) : Socket::IPAddress | Symbol?
      resolved_ips = Utils::IPValidator.resolve_host(host)
      if resolved_ips.empty?
        return unless @config.ssrf_protection?
        @config.log_debug "fetch_url: DNS resolution failed for '#{host}'"
        return :blocked
      end

      return resolved_ips.first unless @config.ssrf_protection?

      resolved_ips.each do |ip|
        if Utils::IPValidator.private_address?(ip)
          @config.log_debug "fetch_url: SSRF blocked - host=#{host} ip=#{ip.address} reason=private_address"
          return :blocked
        end
      end

      resolved_ips.first
    end

    private def response_valid?(response : HTTP::Client::Response, options : ThemeOptions) : Bool
      return false unless response.status_code == 200

      content_type = response.headers["Content-Type"]?
      if content_type && !content_type.starts_with?("image/")
        @config.log_debug "fetch_url: rejected non-image content-type: #{content_type}"
        return false
      end

      content_length = response.headers["Content-Length"]?
      if content_length
        begin
          length = content_length.to_i64
          if length > options.max_file_size
            @config.log_debug "fetch_url: rejected due to Content-Length: #{length}"
            return false
          end
        rescue
        end
      end

      true
    end

    private def stream_body(body_io : IO, max_size : Int64) : Slice(UInt8)?
      buffer = IO::Memory.new(Math.min(max_size, 64 * 1024).to_i)
      chunk = Bytes.new(8192)
      loop do
        read_bytes = body_io.read(chunk)
        break if read_bytes == 0
        remaining = max_size - buffer.bytesize
        if remaining <= 0
          @config.log_debug "fetch_url: response body exceeded max_file_size during streaming"
          return
        end
        buffer.write(chunk[0, Math.min(read_bytes, remaining.to_i)])
      end
      buffer.to_slice
    end

    private def connect_to_ip(ip : Socket::IPAddress, original_host : String, port : Int32, use_tls : Bool) : HTTP::Client
      tcp = TCPSocket.new(ip.address, port)
      begin
        io : IO = tcp
        if use_tls
          io = OpenSSL::SSL::Socket::Client.new(tcp, hostname: original_host)
        end
        HTTP::Client.new(io, original_host)
      rescue ex
        tcp.close rescue nil
        raise ex
      end
    end
  end
end
