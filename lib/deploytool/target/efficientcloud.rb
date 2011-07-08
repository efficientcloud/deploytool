require 'highline'

class DeployTool::Target::EfficientCloud < DeployTool::Target
  SUPPORTED_API_VERSION = 1
  def self.parse_target_spec(target_spec)
    server, app_id = target_spec.split('@').reverse
    if app_id.nil?
      app_id = server.split('.', 2).first
    end
    [server, 'api.' + server, 'api.' + server.split('.', 2).last].each do |api_server|
      begin
        return [app_id.gsub('app', '').to_i, api_server] if check_version(api_server)
      rescue => e
        puts e
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
    @api_server = options['api_server']
    @api_client = ApiClient.new(options['api_server'], options['app_id'], options['email'], options['password'])
  end

  def self.check_version(api_server)
    begin
      info = get_json_resource("http://%s/info" % api_server)
    rescue => e
      $logger.debug "Exception: %s\n%s" % [e.message, e.backtrace.join("\n")]
      return false
    end
    return false unless info['name'] == "efc"

    if info['api_version'] > SUPPORTED_API_VERSION
      raise "ERROR: This version of deploytool is outdated.\nThis server requires at least API Version #{info['api_version']}."
    end
    return true
  end

  def self.create(target_spec)
    puts "Please specify your controlpanel login information"
    email =    HighLine.new.ask("E-mail:   ")
    password = HighLine.new.ask("Password: ") {|q| q.echo = "*" }
    app_id, api_server = parse_target_spec(target_spec)
    EfficientCloud.new('api_server' => api_server, 'app_id' => app_id, 'email' => email, 'password' => password)
  end
  
  def push(opts)
    self.class.check_version(@api_server)
    code_token = @api_client.upload
    deploy_token = @api_client.deploy(code_token)
    @api_client.deploy_status(deploy_token, opts) # Blocks till deploy is done
  end
end

require 'deploytool/target/efficientcloud/api_client'
