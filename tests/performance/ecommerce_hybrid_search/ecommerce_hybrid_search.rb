# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require_relative 'ecommerce_hybrid_search_base'

class EcommerceHybridSearchTest < EcommerceHybridSearchTestBase

  def test_hybrid_search
    set_description("Test performance of hybrid search using an E-commerce dataset (feeding, queries, re-feeding with queries)")
    deploy(selfdir + "app")
    @container = vespa.container.values.first
    start
    benchmark_feed(feed_file_name(), "feed")
    benchmark_query("vespa_queries-weak_and-10k.json", "after_feed", "weak_and")
    benchmark_query("vespa_queries-semantic-10k.json", "after_feed", "semantic")
    benchmark_query("vespa_queries-hybrid-10k.json", "after_feed", "hybrid")
  end

  def feed_file_name(minimal=false)
    minimal ? "vespa_feed-10k.json.zst" : "vespa_feed-1M.json.zst"
  end

  def benchmark_feed(feed_file, label)
    node_file = download_file(feed_file, vespa.adminserver)
    system_sampler = Perf::System::new(vespa.search["search"].first)
    system_sampler.start
    fillers = [parameter_filler("label", label), system_metric_filler(system_sampler)]
    run_feeder(node_file, fillers, {:client => :vespa_feed_client,
                                    :localfile => true,
                                    :silent => true,
                                    :disable_tls => false})
  end

  def benchmark_query(query_file, query_phase, query_type)
    run_fbench_helper(query_file, query_phase, query_type, @container)
  end

end
