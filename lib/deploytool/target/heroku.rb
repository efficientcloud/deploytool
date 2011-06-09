class DeployTool::Target::Heroku < DeployTool::Target
  def self.matches?(target_name)
    target_name[/\.heroku\.com$/]
  end
  
  def to_h
    {:type => "Heroku", :app_name => @app_name}
  end
  
  def initialize(options)
    @app_name = options['app_name']
  end
  
  def self.create(target_name)
    app_name = target_name.gsub('.heroku.com', '')
    puts `heroku create #{app_name}`
    Heroku.new('app_name' => app_name)
  end
  
  def push
    puts `git push git@heroku.com:#{@app_name}.git master`
  end
end