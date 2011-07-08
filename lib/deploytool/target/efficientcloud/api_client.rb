require 'rexml/document'
require 'addressable/uri'
require 'net/http'
require 'net/http/post/multipart'
require 'fileutils'
require 'tempfile'
require 'zip'

class DeployTool::Target::EfficientCloud
  class ApiClient
    attr_reader :server, :app_id, :email, :password
    def initialize(server, app_id, email, password)
      @app_id = app_id
      @server = server
      @email = email
      @password = password
    end
    
    def call(method, method_name, data = {})
      url = Addressable::URI.parse("http://#{@server}/api/cli/v1/apps/#{@app_id}/#{method_name}")
      data = data.merge(:email => @email, :password => @password)
      if method == :post
        res = Net::HTTP.start(url.host, url.port) do |http|
          http.request Net::HTTP::Post::Multipart.new(url.path, data)
        end
      else
        url.query_values = data
        res = Net::HTTP.get_response(url)
      end
      case res
      when Net::HTTPSuccess, Net::HTTPRedirection
        res.body
      else  
        res.error!
      end
    end
    
    def upload
      appfiles = Dir.glob('**/*', File::FNM_DOTMATCH).reject {|f| File.directory?(f) || f[/(^|\/).{1,2}$/] || f[/^.git\//] || f[/^.deployrc$/] || f[/(^|\/).DS_Store$/] }
      
      # Construct a temporary zipfile
      tempfile = Tempfile.open("ecli-upload.zip")
      Zip::ZipOutputStream.open(tempfile.path) do |z|
        appfiles.each do |appfile|
          z.put_next_entry appfile
          z.print IO.read(appfile)
        end
      end
      
      initial_response = call :post, 'upload', {:code => UploadIO.new(tempfile, "application/zip", "ecli-upload.zip")}
      doc = REXML::Document.new initial_response
      doc.elements["code/code-token"].text
    rescue Net::HTTPServerException => e
      case e.response
      when Net::HTTPNotFound
        puts "ERROR: Application app%d.%s couldn't be found." % [@app_id, @server.gsub('api.', '')]
      when Net::HTTPUnauthorized
        puts "ERROR: You're not authorized to update app%d.%s." % [@app_id, @server.gsub('api.', '')]
      else
        raise e
      end
      puts ""
      puts "Please check the controlpanel for update instructions."
      exit 2
    end
    
    def deploy(code_token)
      initial_response = call :post, 'deploy', {:code_token => code_token}
      doc = REXML::Document.new initial_response
      deploy_token = doc.elements["deploy/token"].text
      puts deploy_token.inspect
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
      rc = 0

      while true
        sleep 1
        resp = call :get, 'deploy_status', {:deploy_token => deploy_token}
        doc = REXML::Document.new resp
        
        if doc.elements["deploy/message"].nil?
          puts resp
          puts "...possibly done."
          break
        end
        if doc.elements["deploy/message"].text == 'nojob'
          puts "FINISHED after %d seconds!" % (Time.now-start)
          break
        end
        
        status = doc.elements["deploy/message"].text.gsub('["', '').gsub('"]', '')
        logs = doc.elements["deploy/logs"].text rescue nil
        if logs
          puts logs
          timing << [Time.now-start, status, logs]
        else
          timing << [Time.now-start, status]
          if status == 'error'
            if logs.nil? or logs.empty?
              puts "ERROR after %d seconds!" % (Time.now-start)
              rc = 2
              break
            end
          elsif status != 'build'
            puts "%d: %s" % [Time.now-start, status]
          end
        end
      end
      save_timing_data timing if opts[:timing]
      rc
    end
  end
end

