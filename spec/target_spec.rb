require 'spec_helper'

describe DeployTool::Target do
  context "Target selection" do
    before do
      stub.any_instance_of(HighLine).ask do |q, |
        if q[/E-mail/]
          "demo@efficientcloud.com"
        elsif q[/Password/]
          "demo"
        else
          nil
        end
      end
      
      # TODO: Mock HTTP get method
    end
    
    ["api.cloudfoundry.com", "cloudfoundry.com", "awesomeapp.cloudfoundry.com"].each do |target_spec| #, "api.cloud.1and1.com", "cloud.1and1.com", "awesomeapp.cloud.1and1.com"].each do
      it "should detect #{target_spec} as a CloudFoundry target" do
        DeployTool::Target.find(target_spec).class.should == DeployTool::Target::CloudFoundry
      end
    end
    
    ["app10000@api.srv.io", "app10000@srv.io", "app10000@app123.srv.io", "app10000.srv.io"].each do |target_spec|
      it "should detect #{target_spec} as an Efficient Cloud target" do
        DeployTool::Target.find(target_spec).class.should == DeployTool::Target::EfficientCloud
      end
    end
    
    ["heroku.com", "awesomeapp.heroku.com"].each do |target_spec|
      it "should detect #{target_spec} as an Heroku target" do
        DeployTool::Target.find(target_spec).class.should == DeployTool::Target::Heroku
      end
    end
    
    ["gandi.net", "1and1.com"].each do |target_spec|
      it "should return an error with #{target_spec} as target" do
        DeployTool::Target.find(target_spec).class.should == NilClass
      end
    end
  end
end