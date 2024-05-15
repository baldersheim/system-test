# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'test/unit'
require 'document'
require 'document_set'

class DocumentSetTest < Test::Unit::TestCase

  def test_to_json
    docs = DocumentSet.new

    doc = Document.new('music', 'id:foo:music::1')
    doc.add_field('foo', 1)
    doc.add_field('bar', "some text")
    docs.add(doc)

    doc = Document.new('music', 'id:foo:music::2')
    doc.add_field('foo', 2)
    doc.add_field('bar', "some other text")
    docs.add(doc)


    json = docs.to_json
    expected = [
      {"put"=>"id:foo:music::1", "fields"=>{"bar"=>"some text", "foo"=>1}},
      {"put"=>"id:foo:music::2", "fields"=>{"bar"=>"some other text", "foo"=>2}}
    ]
    assert_equal(expected, JSON.parse(json))
  end

end
