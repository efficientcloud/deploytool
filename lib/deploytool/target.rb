class DeployTool::Target
  def self.find(target_name)
    EfficientCloud.create(target_name)
  end
end

require 'deploytool/target/efficientcloud'