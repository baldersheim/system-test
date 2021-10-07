# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class ErrorReportingTest < IndexedSearchTest

  def setup
    set_owner('arnej')
  end

  def test_missing_attribute_in_grouping_reported
    add_ignorable_messages([/Could not locate attribute for grouping/])
    deploy_app(SearchApp.new.sd(selfdir+"test1.sd").sd(selfdir+"test2.sd"))
    start

    feed_and_wait_for_docs('test1', 3, :file => "#{selfdir}/docs-t1.json")
    feed_and_wait_for_docs('test2', 3, :file => "#{selfdir}/docs-t2.json")

    grouping = 'all(all(group(a) each(output(count()))) all(group(b) each(output(count(),sum(e)))))'
    q = 'query=a:a2&format=json&select=' + grouping

    #save_result(q, selfdir + 'res.json')

    result = search(q)
    puts "RESULT: >>>\n#{result.xmldata}\n<<<\n"
    json = JSON.parse(result.xmldata)
    puts "parsed as JSON>>>\n#{json}\n"

    err_list = json['root']['errors']
    assert(err_list, 'Result should contain "errors" as child of root')
    first_err = err_list[0]
    assert_equal('Error in search reply.', first_err['summary'])
    msg = first_err['message']
    assert(msg =~ /^Could not locate attribute for grouping/, "Wrong message: #{msg}")
  end

  def teardown
    stop
  end

end
