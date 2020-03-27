# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class GeoNnsTest < IndexedSearchTest

  def setup
    set_owner("arnej")
  end

  def geo_check(lat, lon, query_props = {})
    query_props[:x_0] = lat
    query_props[:x_1] = lon
    query = get_query(query_props)
    puts "geo_check(): query='#{query}'"
    result = search(query)
    puts "hits: #{result.hit.size}"
    if result.hit.size < 10
      result.hit.each do |hit|
        txt = hit.field['text']
        pos = hit.field['pos']
        sfs = JSON.parse(hit.field['summaryfeatures'])
        dsf = sfs['distance(pos)']
        miles = dsf.to_f / 1609.344
        puts "Hit: #{txt}  => #{pos} -> #{miles.to_i} miles"
      end
    end
    query_props[:approx] = "false"
    query = get_query(query_props)
    exact = search(query)
    assert_equal(exact.hit.size, result.hit.size)
    exact.hit.zip(result.hit).each do |exp_hit, act_hit|
      assert_equal(exp_hit, act_hit)
    end
  end

  def split_line(line)
    lld = line.chomp.split(':')
    assert_equal(3, lld.size)
    lat, lon, txt = lld
    place = {:lat => lat, :lon => lon, :txt => txt}
  end

  def feed_doc(idx, place)
    doc = Document.new("geo", "id:test:geo::#{idx}").
          add_field("pos", { "values" => [place[:lat], place[:lon]] }).
          add_field("text", place[:txt])
    vespa.document_api_v1.put(doc, {:brief => true})
  end

  def geo_deploy
    app = SearchApp.new.
        sd(selfdir + "geo.sd").
        search_dir(selfdir + "search").
        threads_per_search(1).
        enable_http_gateway
    deploy_app(app)
  end

  def test_geo_airports
    set_description("Test the nearest neighbor search operator for geo search")
    geo_deploy
    start
    i=0
    places = []
    File.open(selfdir + 'airports.txt').each_line do |line|
      place = split_line(line)
      places.push(place)
      feed_doc(i, place)
      i += 1
    end
    puts "Done put of #{i} documents"
    places.each do |place|
      geo_check(place[:lat], place[:lon], {:target_num_hits => 4})
    end
    assert_hitcount('query=sddocname:geo', i)
  end

  def test_geo_cities
    set_description("Test the nearest neighbor search operator for geo search")
    geo_deploy
    start
    i=0
    Zlib::GzipReader.open(selfdir + 'c500-r.txt.gz').each_line do |line|
      place = split_line(line)
      feed_doc(i, place)
      i += 1
      if ((i % 5000) == 0)
        puts "Doc #{i} latitude #{place[:lat]} longitude #{place[:lon]} : #{place[:txt]}"
        break
      end
    end
    puts "Done put of #{i} documents"
    assert_hitcount('query=sddocname:geo', i)
    geo_check(63.0, 10.0, {:target_num_hits => 100})
    places = []
    File.open(selfdir + 'airports.txt').each_line do |line|
      places.push(split_line(line))
    end
    places.each do |place|
      [ 50, 7 ].each do |numhits|
        geo_check(place[:lat], place[:lon], {:target_num_hits => numhits})
      end
    end
  end

  def get_query(qprops)
    x_0 = qprops[:x_0] || 0
    x_1 = qprops[:x_1] || 0
    target_num_hits = qprops[:target_num_hits] || 10
    query_tensor = qprops[:query_tensor] || 'qpos_double'
    doc_tensor = qprops[:doc_tensor] || 'pos'
    approx = qprops[:approx]

    result = "yql=select * from sources * where [{\"targetNumHits\": #{target_num_hits},"
    result += "\"approximate\": #{approx}," if approx
    result += "\"label\": \"nns\"}] nearestNeighbor(#{doc_tensor},#{query_tensor})"
    result += ";&ranking.features.query(#{query_tensor})={{x:0}:#{x_0},{x:1}:#{x_1}}"
    result += "&hits=#{target_num_hits}"
    return result
  end

  def teardown
    stop
  end
end
