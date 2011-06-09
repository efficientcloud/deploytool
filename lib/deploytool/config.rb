require 'inifile'

class DeployTool::Config
  def self.[](section)
    @@configfile[section]
  end
  def self.[]=(section, value)
    @@configfile[section] = value
  end
  
  def self.load(filename)
    @@configfile = IniFile.load(filename)
  end
  
  def self.save
    @@configfile.save
  end
end