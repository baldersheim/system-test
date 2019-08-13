# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'multi_provider_storage_test'
require 'gatewayxmlparser'

# Test to see if "header" and "body" settings are allowed
# (they are ignored on Vespa 7, so this test just shows that deployment works)
# TODO: Remove this test in Vespa 8

class HeaderBodyTest < MultiProviderStorageTest

  def setup
    set_owner("arnej")
    deploy_app(default_app.sd(selfdir+"v1/music.sd"))
    start
    @doc1 = Document.new("music", "id:storage_test:music:n=1234:1").
      add_field("title", "whatever title").
      add_field("one", "field 1").
      add_field("two", "field 2").
      add_field("tre", "field 3").
      add_field("fir", "field 4")
    @doc2 = Document.new("music", "id:storage_test:music:n=2345:6").
      add_field("title", "six title").
      add_field("one", "six 1").
      add_field("two", "six 2").
      add_field("tre", "six 3").
      add_field("fir", "six 4")
  end

  def self.testparameters
    { "PROTON" => { :provider => "PROTON" } }
  end

  def doInserts
    puts "Insert - START"
    vespa.document_api_v1.put(@doc1)
    vespa.document_api_v1.put(@doc2)
    puts "Insert - DONE"
  end

  def visit
    args = "--xmloutput"
    java_xml = vespa.adminserver.execute("vespa-visit " + args)
    #puts "\nGOT xml >>>"
    #puts java_xml
    #puts "<<< xml GOT\n"
    java_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?> <result>" + java_xml + "</result>"
    parser_java = GatewayXMLParser.new(java_xml)
    parser_java.documents.sort! {|a,b| a.documentid <=> b.documentid}
    return parser_java.documents
  end

  # Start visitor and check how many docs we get back
  def checkVisiting
    results = visit
    puts " => " + results.length.to_s + " documents visited"
    return results.length
  end

  def test_with_visit
    # Run a visitor before inserting to make sure storage is empty
    numResults = checkVisiting()
    puts "numResults before insert is " + numResults.to_s
    assert_equal(0, numResults)
    doInserts()

    numResults = checkVisiting()
    puts "numResults after insert is " + numResults.to_s
    assert_equal(2, numResults)

    visiteddocs = visit()
    correctdocs = [ @doc1, @doc2 ]
    assert_equal(correctdocs.sort, visiteddocs.sort)
  end

  def teardown
    stop
  end
end
