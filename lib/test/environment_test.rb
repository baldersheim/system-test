# Copyright Vespa.ai. All rights reserved.

require 'test/unit'
require 'environment'

class EnvironmentTest < Test::Unit::TestCase

  def test_access_environment
    # (Just running the code as the result depends on the environment)
    puts "Environment.instance.vespa_home=#{Environment.instance.vespa_home}"
    puts "Environment.instance.vespa_web_service_port=#{Environment.instance.vespa_web_service_port}"
  end

end
