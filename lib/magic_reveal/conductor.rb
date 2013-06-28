require 'magic_reveal'
require 'net/https'
require 'archive/zip'
require 'pathname'
require 'fileutils'

module MagicReveal
  # Fetchs a github zip file and unpacks it for use.
  class Conductor
    attr_reader :url, :enable_warnings

    def initialize url=nil
      self.url = url unless url.nil?
    end

    def url= url
      @url = URI.parse url
    end

    def fetch save_path, limit = 5
      raise TooManyRedirects if limit <= 0

      request = Net::HTTP::Get.new url.path
      response = Net::HTTP.start(url.host, url.port, use_ssl: url.scheme == 'https') { |http| http.request(request)  }

      case response
      when Net::HTTPSuccess then
        File.write(save_path, response.body)
      when Net::HTTPRedirection then
        self.url = response['location']
        warn "redirected to #{url}" if enable_warnings
        fetch(save_path, limit - 1)
      else
        raise Error, "Huh? #{response.value}"
      end
    end

    def unpack zip_file, directory
      directory = Pathname.new directory
      raise Error, "Directory '#{directory}' already exists." if directory.exist?

      Archive::Zip.extract zip_file.to_s, directory.to_s

      # Unwrap the outer-most unzipped directory.
      wrapper_dir = directory.children.first
      wrapper_dir.children.each { |c| c.rename(directory + c.basename)  }
      wrapper_dir.rmdir
    end
  end
end
