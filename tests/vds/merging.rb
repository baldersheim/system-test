# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'persistent_provider_test'

class MergingTest < PersistentProviderTest

  def setup
    set_owner("vekterli")
  end

  def timeout_seconds
    1800
  end

  def teardown
    stop
  end

  def test_merging
    deploy_app(default_app.num_nodes(2).redundancy(2))
    run_merging_test
  end

  def test_merging_with_one_distributor_stripe
    # TODO STRIPE: Remove this test when new distributor stripe mode is default
    deploy_app(default_app.num_nodes(2).redundancy(2).num_distributor_stripes(1))
    run_merging_test
  end

  def run_merging_test
    start
    # Take down one node
    vespa.stop_content_node("storage", "1")

    doc1_id = "id:storage_test:music:n=123:thequickbrownfoxjumpsoverthelazydogperhapsyoushouldexercisemoredog"
    doc2_id = "id:storage_test:music:n=123:lookatthisfancydocumentidjustlookatitmygoodnesshowfancyitis"

    # Feed to the other
    doc = Document.new("music", doc1_id)
    vespa.document_api_v1.put(doc)

    # Switch which nodes are up
    vespa.start_content_node("storage", "1")
    vespa.stop_content_node("storage", "0")

    vespa.storage["storage"].wait_until_ready

    # Feed another document

    doc = Document.new("music", doc2_id)
    vespa.document_api_v1.put(doc)

    # Take both nodes back up
    vespa.start_content_node("storage", "0")
    vespa.storage["storage"].wait_until_ready

    # Check that both documents are on both nodes
    statinfo = vespa.storage["storage"].storage["0"].stat(doc1_id)
    assert(statinfo.has_key?("0"))
    assert(statinfo.has_key?("1"))

    statinfo = vespa.storage["storage"].storage["0"].stat(doc2_id)
    assert(statinfo.has_key?("0"))
    assert(statinfo.has_key?("1"))
  end

  def test_ensure_merge_handler_gets_new_document_config
    deploy_app(make_merge_app(1))
    start
    feedfile(VDS + 'musicdata.xml')

    # Deploy app with new document type. Feeding will work as the merge handler
    # is not involved in this scope.
    deploy_app_and_wait_until_config_has_been_propagated(make_merge_app(1, true))
    feedfile(VDS + 'banana.xml')
    
    # Increase redundancy, forcing merge of documents with new doc type between
    # the nodes. Will fail unless merge handler properly uses the new document
    # config.
    deploy_app_and_wait_until_config_has_been_propagated(make_merge_app(2, true))
    wait_until_ready # will time out if merging fails
  end

  def make_merge_app(num_copies, include_2nd_doctype = false)
    app = default_app.num_nodes(2).
            redundancy(num_copies) # music SD added by default
    if include_2nd_doctype
      app.sd(VDS + 'schemas/banana.sd')
    end
    app
  end

  def deploy_app_and_wait_until_config_has_been_propagated(app)
    gen = get_generation(deploy_app(app)).to_i
    vespa.storage['storage'].wait_until_content_nodes_have_config_generation(gen)
    wait_for_config_generation_proxy(gen)
    if @valgrind
        # proton ups generation before all config has been processed.
        sleep 30
    end
  end

end
