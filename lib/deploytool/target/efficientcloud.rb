require 'highline'

class DeployTool::Target::EfficientCloud < DeployTool::Target
  def self.parse_target_spec(target_spec)
    server, app_id = target_spec.split('@').reverse
    if app_id.nil?
      app_id = server.split('.', 2).first
    end
    [server, 'api.' + server, 'api.' + server.split('.', 2).last].each do |api_server|
      begin
        return [app_id.gsub('app', '').to_i, api_server] if get_json_resource("http://%s/info" % api_server)['name'] == "efc"
      rescue => e
        $logger.debug "Exception: %s\n%s" % [e.message, e.backtrace.join("\n")]
      end
    end
    nil
  end
  
  def self.matches?(target_spec)
    return true if parse_target_spec(target_spec)
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
  
  def self.create(target_spec)
    puts "Please specify your controlpanel login information"
    email =    HighLine.new.ask("E-mail:   ")
    password = HighLine.new.ask("Password: ") {|q| q.echo = "*" }
    app_id, api_server = parse_target_spec(target_spec)
    EfficientCloud.new('api_server' => api_server, 'app_id' => app_id, 'email' => email, 'password' => password)
  end
  
  def push
    code_token = @api_client.upload
    deploy_token = @api_client.deploy(code_token)
    @api_client.deploy_status(deploy_token) # Blocks till deploy is done
  end
end

require 'deploytool/target/efficientcloud/api_client'