# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class AccessLogTest < IndexedStreamingSearchTest

  def setup
    set_owner("bjorncs")
    set_description("Verify that search request are stored in default access log format")
    deploy_app(SearchApp.new.
               container(Container.new.
                   search(Searching.new).
                   documentapi(ContainerDocumentApi.new).
                   docproc(DocumentProcessing.new).
                   component(AccessLog.new("vespa").
                       fileNamePattern("logs/vespa/access/QueryAccessLog.default").
                       compressOnRotation("false"))).
               sd(SEARCH_DATA+"music.sd"))
    start
  end

  def test_accesslog
    feed_and_wait_for_docs("music", 777, :file => SEARCH_DATA+"music.777.json")

    assert_hitcount("query=sddocname:music", 777)
    sleep 10 # wait for log to be written to disk
    container = vespa.container.values.first
    container.stop
    log = container.get_query_access_log

    puts "LOG:'" + log + "'"

    monitor_line = Regexp.new('.* \/monitor\.html')
    correct_format = Regexp.new('(\S+) (\S+) (\S+) \[([^:]+):(\d+:\d+:\d+) ([^\]]+)\] "(\S+) (.*?) (\S+) (\S+) (\S+)')

    count = 0
    log.each_line { |line|
      if line =~ monitor_line
        # ignore lines generated by other processes
      elsif line =~ correct_format
        count = count + 1
      end
    }

    assert(count >= 1)

    puts log.inspect

    connection_log = container.get_connection_log
    puts "CONNECTION LOG:'" + connection_log + "'"
    assert_match(/HTTP\/1.1/, connection_log)
  end

  def teardown
    stop
  end

end
