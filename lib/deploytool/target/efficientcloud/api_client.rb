require 'rexml/document'
require 'addressable/uri'
require 'net/http'
require 'net/http/post/multipart'

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
      if res.code != '200'
        puts "Calling '%s' returned %s, exiting" % [url, res.code, res.body]
        exit 2
      end
      res.body
    end
    
    def upload
      # TODO: FAIL if no Rakefile in current directory
      
      puts `find . | zip -9q .ecli-upload.zip -@`
      initial_response = nil
      File.open(".ecli-upload.zip") do |file|
        initial_response = call :post, 'upload', {:code => UploadIO.new(file, "application/zip", "ecli-upload.zip")}
      end
      doc = REXML::Document.new initial_response
      doc.elements["code/code-token"].text
    end
    
    def deploy(code_token)
      initial_response = call :post, 'deploy', {:code_token => code_token}
      doc = REXML::Document.new initial_response
      deploy_token = doc.elements["deploy/token"].text
      puts deploy_token.inspect
      deploy_token
    end
    
    def deploy_status(deploy_token)
      i = 0
      while true
        sleep 1
        i += 1
        resp = call :get, 'deploy_status', {:deploy_token => deploy_token}
        doc = REXML::Document.new resp
        
        if doc.elements["deploy/message"].nil?
          puts resp
          puts "...possibly done."
          break
        end
        if doc.elements["deploy/message"].text == 'nojob'
          puts "FINISHED after #{i} seconds!"
          break
        end
        
        status = doc.elements["deploy/message"].text.gsub('["', '').gsub('"]', '')
        logs = doc.elements["deploy/logs"].text rescue nil
        if logs
          puts logs
        else
          if status == 'error'
            puts "ERROR after #{i} seconds!"
            exit 2
          elsif status != 'build'
            puts "#{i}: #{status}"
          end
        end
      end
    end
  end
end

