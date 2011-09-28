require 'rexml/document'
require 'addressable/uri'
require 'net/http'
require 'net/http/post/multipart'
require 'fileutils'
require 'tempfile'
require 'zip'
require 'oauth2'
require 'multi_json'
require 'highline'

CLIENT_ID = 'com.efficientcloud.api.deploytool'
CLIENT_SECRET = '11d6b5cc70e4bc9563a3b8dd50dd34f6'

class DeployTool::Target::EfficientCloud
  class ApiClient
    attr_reader :server, :app_name, :email, :password, :refresh_token, :auth_method
    def initialize(server, app_name, auth)
      @app_name = app_name
      @server = server
      if auth.has_key? :refresh_token
        @refresh_token = auth[:refresh_token]
        @auth_method = :refresh_token
      elsif auth.has_key? :email
        @auth_method = :password
        @email = auth[:email]
        @password = auth[:password]
      else
        @auth_method = :password
      end
    end

    def re_auth
      @auth_method = :password
    end
    
    def call(method, method_name, data = {})
      url = Addressable::URI.parse("http://#{@server}/api/cli/v1/apps/#{@app_name}/#{method_name}")
      client = OAuth2::Client.new(CLIENT_ID, CLIENT_SECRET, :site => "http://#{server}/", :token_url => '/oauth2/token', :raise_errors => false) do |builder|
        builder.use Faraday::Request::Multipart
        builder.use Faraday::Request::UrlEncoded
        builder.adapter :net_http
      end
      auth = false
      tries = 0
      while not auth
        token = nil
        handled_error = false
        begin
          if @auth_method == :password
            if tries != 0 && HighLine.new.ask("Would you like to try again? (y/n): ") != 'y'
              return
            end
            if !@email.nil? && !@password.nil?
              # Upgrade from previous configuration file
              print "Logging in..."
              begin
                token = client.password.get_token(@email, @password, :raise_errors => true)
                token = token.refresh!
                @email = nil
                @password = nil
              rescue StandardError => e
                @email = nil
                @password = nil
                tries = 0
                retry
              ensure
                print "\r"
              end
            else
              tries += 1
              $logger.info "Please specify your %s login data" % [DeployTool::Target::EfficientCloud.cloud_name]
              email =    HighLine.new.ask("E-mail:   ")
              password = HighLine.new.ask("Password: ") {|q| q.echo = "*" }
              print "Authorizing..."
              begin
                token = client.password.get_token(email, password, :raise_errors => true)
                token = token.refresh!
              ensure
                print "\r"
              end
              puts "Authorization succeeded."
            end
          else
            params = {:client_id      => client.id,
                      :client_secret  => client.secret,
                      :grant_type     => 'refresh_token',
                      :refresh_token  => @refresh_token
                      }
            token = client.get_token(params)
          end
        rescue OAuth2::Error => e
          handled_error = true
          print "Authorization failed"
          token = nil
          details = MultiJson.decode(e.response.body) rescue nil
          if details
            puts ": #{details['error_description']}"
            re_auth if details['error']
          else
            puts "."
          end
        rescue EOFError
          exit 1
        rescue Interrupt
          exit 1
        rescue StandardError => e
          puts "ERROR: #{e.inspect}"
          puts "\nPlease contact %s support: %s" % [EfficientCloud.cloud_name, EfficientCloud.support_email]
          puts ""
        end
        auth = token
        if not token and not handled_error
          puts "Authorization failed."
        end
      end
      
      @refresh_token = token.refresh_token
      @auth_method = :refresh_token

      response = token.request(method, url.path, method==:post ? {:body => data} : {:params => data})
      if response.status != 200
        details = MultiJson.decode(response.body) rescue nil
        raise "#{response.status} #{details}"
      end
      response
    end

    def to_h
      {:server => @server, :app_name => @app_name, :email => email, :password => @password, :refresh_token => @refresh_token, :auth_method => @auth_method}
    end

    def info
      response = call :get, 'info'
      return nil if not response
      doc = REXML::Document.new response.body
      data = {}
      doc.elements["app"].each_element do |el|
        data[el.name.gsub('-','_').to_sym] = el.text
      end
      data
    end
    
    def upload
      puts "-----> Packing code tarball..."
      
      ignore_regex = [
        /(^|\/).{1,2}$/,
        /(^|\/).git\//,
        /^.deployrc$/,
        /^log\//,
        /(^|\/).DS_Store$/,
        /(^|\/)[^\/]+\.(bundle|o|so|rl|la|a)$/,
        /^vendor\/gems\/[^\/]+\/ext\/lib\//
      ]
      
      appfiles = Dir.glob('**/*', File::FNM_DOTMATCH)
      appfiles.reject! {|f| File.directory?(f) }
      appfiles.reject! {|f| ignore_regex.map {|r| !f[r] }.include?(false) }
      
      # TODO: Shouldn't upload anything that's in gitignore
      
      # Construct a temporary zipfile
      tempfile = Tempfile.open("ecli-upload.zip")
      Zip::ZipOutputStream.open(tempfile.path) do |z|
        appfiles.each do |appfile|
          z.put_next_entry appfile
          z.print IO.read(appfile)
        end
      end
      
      puts "-----> Uploading %s code tarball..." % human_filesize(tempfile.path)
      initial_response = call :post, 'upload', {:code => Faraday::UploadIO.new(tempfile, "application/zip")}
      doc = REXML::Document.new initial_response.body
      doc.elements["code/code-token"].text
    end

    def deploy(code_token)
      initial_response = call :post, 'deploy', {:code_token => code_token}
      return nil if not initial_response
      doc = REXML::Document.new initial_response.body
      deploy_token = doc.elements["deploy/token"].text
      deploy_token
    end

    def save_timing_data(data)
      File.open('deploytool-timingdata-%d.json' % (Time.now), 'w') do |f|
        f.puts data.to_json
      end
    end

    def deploy_status(deploy_token, opts)
      start = Time.now
      timing = []
      previous_status = nil
      print "-----> Started deployment '%s'" % deploy_token
      
      while true
        sleep 1
        resp = call :get, 'deploy_status', {:deploy_token => deploy_token}
        doc = REXML::Document.new resp.body
        
        if doc.elements["deploy/message"].nil?
          puts resp
          puts "...possibly done."
          break
        end
        if doc.elements["deploy/message"].text == 'finished'
          puts "\n-----> FINISHED after %d seconds!" % (Time.now-start)
          break
        end
        
        status = doc.elements["deploy/message"].text.gsub('["', '').gsub('"]', '')
        if previous_status != status
          case status
          when "build"
            puts "\n-----> Building/updating virtual machine..."
          when "deploy"
            print "\n-----> Copying virtual machine to app hosts"
          when "publishing"
            print "\n-----> Updating HTTP gateways"
          when "cleanup"
            print "\n-----> Removing old deployments"
          end
          previous_status = status
        end
        
        logs = doc.elements["deploy/logs"].text rescue nil
        if logs
          puts "" if status != "build" # Add newline after the dots
          puts logs
          timing << [Time.now-start, status, logs]
        else
          timing << [Time.now-start, status]
          if status == 'error'
            if logs.nil? or logs.empty?
              raise "ERROR after %d seconds!" % (Time.now-start)
            end
          elsif status != "build"
            print "."
            STDOUT.flush
          end
        end
      end
    ensure
      save_timing_data timing if opts[:timing]
    end
    
    def human_filesize(path)
      size = File.size(path)
      units = %w{B KB MB GB TB}
      e = (Math.log(size)/Math.log(1024)).floor
      s = "%.1f" % (size.to_f / 1024**e)
      s.sub(/\.?0*$/, units[e])
    end
  end
end

