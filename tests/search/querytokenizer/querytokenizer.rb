# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class QueryTokenizer < IndexedSearchTest

  def setup
    set_owner("arnej")
    set_description("Test what the query tokenizer is doing")
  end

  def test_combine
    deploy_app(SearchApp.new.sd(selfdir + "combine.sd"))
    start

    feed_and_wait_for_docs("combine", 1, :file => selfdir+"doc-combine.xml")
    assert_hitcount("text", 1)

    assert_hitcount("one:foo/bar", 1)
    assert_hitcount("one:qux/baz", 0)

    assert_hitcount("two:foo/bar", 0)
    assert_hitcount("two:qux/baz", 1)

    # ideally we would like both of these to work,
    # but we should prioritize the first over
    # the second instead of the other way around
    assert_hitcount("both:foo/bar", 1)
    #assert_hitcount("both:qux/baz", 1)
  end

  def test_wordmatch_in_default
    deploy_app(SearchApp.new.sd(selfdir+"wind.sd"))
    start

    feed(:file => selfdir+"doc-wind.xml")

    wait_for_hitcount("sddocname:wind", 1)

    assert_hitcount("one:qux/baz", 0)
    assert_hitcount("two:foo/bar", 0)

    assert_hitcount("one:foo/bar", 1)
    assert_hitcount("two:qux/baz", 1)
  end

  def test_combine_in_default
    deploy_app(SearchApp.new.sd(selfdir+"tinde.sd"))
    start

    feed(:file => selfdir+"doc-tinde.xml")

    wait_for_hitcount("sddocname:tinde", 1)

    assert_hitcount("one:qux/baz", 0)
    assert_hitcount("two:foo/bar", 0)

    assert_hitcount("text:text", 1)

    assert_hitcount("one:foo/bar", 1)
    assert_hitcount("two:qux/baz", 1)
  end


  def teardown
    stop
  end

end
