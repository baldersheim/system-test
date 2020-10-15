# Copyright 2020 Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance_test'
require 'app_generator/search_app'

class DocumentV1Throughput < PerformanceTest

  def initialize(*args)
    super(*args)
  end

  def timeout_seconds
    900
  end

  def setup
    super
    set_description("Stress test document/v1 API POST and GET")
    set_owner("jvenstad")
    @test_config = 
    {
      "GET"  => {
        :metrics => {
          'qps' => { :y_min => 30000, :y_max => 50000 },
          '95p' => { :y_min =>     3, :y_max =>    10 }
        },
        :fbench => { }
      },
      "POST" => {
        :metrics => {
          'qps' => { :y_min => 10000, :y_max => 30000 },
          '95p' => { :y_min =>     3, :y_max =>    20 }
        },
        :fbench => { :use_post => true, :request_body => '{ "fields": { "text": "very short text" } }' }
      }
    }
  end

  def test_throughput
    deploy_app(SearchApp.new.monitoring("vespa", 60).
               container(Container.new("combinedcontainer").
                         jvmargs('-Xms16g -Xmx16g').
                         search(Searching.new).
                         docproc(DocumentProcessing.new).
                         gateway(ContainerDocumentApi.new)).
               admin_metrics(Metrics.new).
               elastic.redundancy(1).ready_copies(1).
               indexing("combinedcontainer").
               sd(selfdir + "text.sd"))

    @graphs = get_graphs(@test_config)

    start
    profiler_start
    benchmark_operations(@test_config)
  end

  def benchmark_operations(methods)
    qrserver = @vespa.container["combinedcontainer/0"]
    paths_file = dirs.tmpdir + "paths.txt"
    qrserver.execute("for i in {1..#{1 << 16}}; do echo '/document/v1/test/text/docid/'$i >> #{paths_file}; done")
    methods.each do |method, config|
      run_fbench2(qrserver,
                  paths_file,
                  [ parameter_filler("HTTP method", method) ],
                  { :clients => 128, :runtime => 120 }.merge(config[:fbench]))
    end
  end

  def get_graphs(methods)
    methods.map do |method, config|
      config[:metrics].map do |metric, limits|
        {
          :x => 'HTTP method',
          :y => metric,
          :title => "/document/v1 HTTP #{method} #{metric}",
          :filter => { 'HTTP method' => method },
          :historic => true
        }.merge(limits)
      end
    end.flatten
  end

  def teardown
    super
  end

end
