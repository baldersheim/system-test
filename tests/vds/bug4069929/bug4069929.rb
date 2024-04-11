# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'vds_test'

class Bug4069929 < VdsTest

  def setup
    set_owner("balder")
    set_description("Test for bug 4069929")

    deploy_app(default_app.sd(selfdir + "music.sd"))
    start
  end

  def test_bug4069929
    feedfile(selfdir+"feed.json")
    vespa.adminserver.execute("vespa-visit -i")
  end

  def teardown
    stop
  end

end
