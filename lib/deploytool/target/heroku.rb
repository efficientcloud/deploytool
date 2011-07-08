class DeployTool::Target::Heroku < DeployTool::Target
  def self.matches?(target_spec)
    target_spec[/(^|\.)heroku\.com$/]
  end
  
  def to_h
    {:type => "Heroku", :app_name => @app_name}
  end
  
  def to_s
    "%s.heroku.com (Heroku)" % [@app_name]
  end
  
  def initialize(options)
    @app_name = options['app_name']
  end
  
  def self.create(target_name)
    app_name = target_name.gsub('.heroku.com', '')
    # TODO: Ask for app name if app name is nil or www
    puts `heroku create #{app_name}`
    Heroku.new('app_name' => app_name)
  end
  
  def push(opts)
    puts `git push git@heroku.com:#{@app_name}.git master`
    $?.exitstatus
  end
end
