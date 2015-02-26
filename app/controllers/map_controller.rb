require 'rest-client'
require 'pg'
require 'rgeo/geo_json'
require 'json'
require 'eventmachine'

class MapController < ApplicationController
  def show_map
    # puts ("trace")
  end

  def insert_iso_shape
    conn = PGconn.open(
      :host => 'aws-gis.cot74qrzzmqu.us-west-2.rds.amazonaws.com',
      :dbname => 'awsgis',
      # :host => 'localhost',
      # :dbname => 'gis',
      :port => 5432,
      :user => 'master',
      :password => 'mastermaster')
      # :user => 'master',

      # :password => 'mastermaster')

    ########################################################
    # some weird shit to get the geo string setup for insertion
    polygon = params[:polygon].to_json()
      # puts "=============="
      # puts polygon
      # puts "============="
    polygon.slice! "{\\\"type\\\":\\\"Feature\\\",\\\"properties\\\":{},\\\"geometry\\\":"
    polygon = polygon.sub("}}", "}")
    polygon = polygon.gsub("\\", "")
    polygon.chop!
    polygon[0] = ''

    insertString = 'insert into user_polygons (name, geom) VALUES ($1, ST_SetSRID(ST_GeomFromGeoJSON($2), 4269)) RETURNING id'
    result = conn.query(insertString, ['Test Insert', polygon])

    # puts "==============="
    # puts result
    # puts "==============="
    row = result.first
    rowID = row['id']
    # puts rowID


    selectString = 'select geoid10 as block_group_id, (st_area(st_intersection(user_polygons.geom, bg_2010.geom))/st_area(bg_2010.geom)) as user_polygon_percent_overlap from bg_2010, user_polygons where user_polygons.id = $1 and ST_INTERSECTS(user_polygons.geom, bg_2010.geom) order by geoid10;'
    result = conn.query(selectString, [rowID])

    puts result.count.to_s + " Block Groups "

    if (result.count == 0)
      render :json => {
        pop: 0,
        hu: 0
    }
    end

    block_group_id = Array.new
    block_group_overlap = Array.new

    result.each do |row|
      #puts row['block_group_id'] + "    " + row['user_polygon_percent_overlap']
      block_group_id.push(row['block_group_id'])
      block_group_overlap.push(row['user_polygon_percent_overlap'])
    end



    n = 0
    totalPopulation = 0
    totalHousehold = 0

    restTime = 0
    while (n < block_group_id.length) do
      puts "Record: " + n.to_s + "   Block Group ID: " + block_group_id[n] + "   Percent Overlap: " + block_group_overlap[n]


      getString = 'http://tigerweb.geo.census.gov/arcgis/rest/services/Census2010/Tracts_Blocks/MapServer/1/'
      getString = getString + 'query?where=GEOID%3D' + block_group_id[n] + '&text=&objectIds=&time=&geometry=&geometryType=esriGeometryPoint&inSR=&spatialRel=esriSpatialRelIntersects&relationParam=&outFields=POP100%2C+HU100%2C+BLKGRP&returnGeometry=false&maxAllowableOffset=&geometryPrecision=&outSR=&returnIdsOnly=false&returnCountOnly=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&returnZ=false&returnM=false&gdbVersion=&returnDistinctValues=false&f=pjson'
      start = Time.now      
      response = RestClient.get getString
      finish = Time.now
      puts (finish - start)
      restTime = restTime + (finish - start)


      # response = RestClient.get 'http://tigerweb.geo.census.gov/arcgis/rest/services/Census2010/Tracts_Blocks/MapServer/1/query?where=GEOID%3D484910208071&text=&objectIds=&time=&geometry=&geometryType=esriGeometryPoint&inSR=&spatialRel=esriSpatialRelIntersects&relationParam=&outFields=POP100%2C+HU100%2C+BLKGRP&returnGeometry=false&maxAllowableOffset=&geometryPrecision=&outSR=&returnIdsOnly=false&returnCountOnly=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&returnZ=false&returnM=false&gdbVersion=&returnDistinctValues=false&f=pjson'
      
      hash = JSON.parse response
      features = hash["features"]
      attributes = features[0]

      # puts attributes["attributes"]["POP100"]
      # puts attributes["attributes"]["HU100"]
      tempPopulation = attributes["attributes"]["POP100"].to_f * block_group_overlap[n].to_f
      tempHousehold = attributes["attributes"]["HU100"].to_f * block_group_overlap[n].to_f

      totalPopulation = totalPopulation + tempPopulation
      totalHousehold = totalHousehold + tempHousehold

      n = n + 1
    end 
    puts "==============="
    puts "restTime: " + restTime.to_s
    puts "REST Calls: " + result.count.to_s
    puts "Avg REST Call: " + (restTime / result.count).to_s
    puts "==============="
    puts ""
    puts "------------"
    puts "POP " + totalPopulation.to_f.floor.to_s
    puts "HU " + totalHousehold.to_f.floor.to_s
    puts "------------"

    render :json => {
      pop: totalPopulation.floor,
      hu: totalHousehold.floor
    }

  end

  def insert_iso

    puts params[:polygon]


      
      # :pool => 5,
      # :timeout => 5000)

    # conn.exec("insert into user_polygons (name, geom) VALUES('Test Polygon 1', ST_SetSRID(ST_MakePolygon(ST_GeomFromText('LINESTRING(-97.73695 30.290746,-97.72974 30.310607,-97.711887 30.315349,-97.707081 30.299936,-97.718067 30.290153, -97.73695 30.290746)')),4269));")
       

    render :json => {
      connection: 'success'
    }   

  end

  def starting_coordinates

    render :json => {
      latitude: 36,
      longitude: -97,
      zoom: 100,
      isGeoLocation: true
    }
    # puts("trace")

    # response = RestClient.get("http://freegeoip.net/json")
    # myData = JSON.parse(response)

    # if (myData.nil?) then
    #   # center of the U.S.
    #   latitude = 35.746512259918504
    #   longitude = -96.9873046875
    #   zoom = 4
    #   isGeoLocation = false
    # else
    #   # geo IP location
    #   latitude = myData['latitude']
    #   longitude = myData['longitude']
    #   zoom = 15
    #   isGeoLocation = true
    # end

    # render :json => {
    #   latitude: latitude,
    #   longitude: longitude,
    #   zoom: zoom,
    #   isGeoLocation: isGeoLocation
    # }


  end
end
