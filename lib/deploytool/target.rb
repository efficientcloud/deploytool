class DeployTool::Target
  def self.find(target_name)
    Heroku.create(target_name)
  end
end

require 'deploytool/target/heroku'