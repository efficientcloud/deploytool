require 'highline'

class DeployTool::Target::EfficientCloud < DeployTool::Target
  def self.matches?(target_spec)
    app_id, api_server = target_spec.split('@')
    get_json_resource("http://%s/info" % api_server)['name'] == "efc" rescue false
  end
  
  def to_h
    {:type => "EfficientCloud", :api_server => @api_client.server, :app_id => @api_client.app_id, :email => @api_client.email, :password => @api_client.password}
  end
  
  def to_s
    "app%s@%s (EFC-based platform)" % [@api_client.app_id, @api_client.server]
  end
  
  def initialize(options)
    @api_client = ApiClient.new(options['api_server'], options['app_id'], options['email'], options['password'])
  end
  
  def self.create(target_app)
    puts "Please specify your controlpanel login information" % target_app
    email =    HighLine.new.ask("E-mail:   ")
    password = HighLine.new.ask("Password: ") {|q| q.echo = "*" }
    
    app_id, api_server = target_app.split('@')
    app_id = app_id.gsub('app', '').to_i
    EfficientCloud.new('api_server' => api_server, 'app_id' => app_id, 'email' => email, 'password' => password)
  end
  
  def push
    code_token = @api_client.upload
    deploy_token = @api_client.deploy(code_token)
    @api_client.deploy_status(deploy_token) # Blocks till deploy is done
  end
end

require 'deploytool/target/efficientcloud/api_client'