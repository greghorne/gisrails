require 'rest-client'
require 'pg'
require 'rgeo/geo_json'
require 'json'
require 'eventmachine'
require 'thread'

class MapController < ApplicationController

  def show_map

  end

  def create_drive_polygon

    longitude = params[:longitude]
    latitude = params[:latitude]
    time = params[:time]

    getString = 'https://route.st.nlp.nokia.com/routing/6.2/calculateisoline.json'
    getString = getString + '?mode=fastest;car;traffic:disabled&start=' + latitude + ',' + longitude + '&time=' + time + '&app_id=hQG4ZX6W0D2sUfQJeb0t&app_code=R82WCNW4u11a93myPTaMpg'

    response = RestClient.get getString

    result = JSON.parse(response)
    
    render :json => {
      result: result
    }

  end


  def insert_iso_shape
    conn = PGconn.open(
      :host => 'aws-gis.cot74qrzzmqu.us-west-2.rds.amazonaws.com',
      :dbname => 'awsgis',
      :port => 5432,
      :user => 'master',
      :password => 'mastermaster')
puts "after conn"
    ########################################################
    # having to strip some characters from GeoJSON string prior
    # to insert into DB
    #
    polygon = params[:polygon].to_json()

    polygon = polygon.gsub("\\", "")
    polygon.chop!
    polygon[0] = ''

# puts polygon

    insertString = 'insert into user_polygons (name, geom) VALUES ($1, ST_SetSRID(ST_GeomFromGeoJSON($2), 4269)) RETURNING id'
    result = conn.query(insertString, [' ', polygon])

    row = result.first
    rowID = row['id']

    selectString = 'select geoid10 as block_group_id, (st_area(st_intersection(user_polygons.geom, bg_2010.geom))/st_area(bg_2010.geom)) as user_polygon_percent_overlap from bg_2010, user_polygons where user_polygons.id = $1 and ST_INTERSECTS(user_polygons.geom, bg_2010.geom) order by geoid10;'
    result = conn.query(selectString, [rowID])
    puts "==============="
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
      block_group_id.push(row['block_group_id'])
      block_group_overlap.push(row['user_polygon_percent_overlap'])
    end

    n = 0
    totalPopulation = 0
    totalHousehold = 0

    counter = 0
    threads = []

    restTime = 0

    start = Time.now()

    while (n < block_group_id.length) do
      # puts "Record: " + n.to_s + "   Block Group ID: " + block_group_id[n] + "   Percent Overlap: " + block_group_overlap[n]

      # getString = 'http://tigerweb.geo.census.gov/arcgis/rest/services/Census2010/Tracts_Blocks/MapServer/1/'
      # getString = getString + 'query?where=GEOID%3D' + block_group_id[n] + '&text=&objectIds=&time=&geometry=&geometryType=esriGeometryPoint&inSR=&spatialRel=esriSpatialRelIntersects&relationParam=&outFields=POP100%2C+HU100%2C+BLKGRP&returnGeometry=false&maxAllowableOffset=&geometryPrecision=&outSR=&returnIdsOnly=false&returnCountOnly=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&returnZ=false&returnM=false&gdbVersion=&returnDistinctValues=false&f=pjson'

      getString = 'http://tigerweb.geo.census.gov/arcgis/rest/services/Census2010/Tracts_Blocks/MapServer/1/'
      getString = getString + 'query?where=GEOID%3D' + block_group_id[n] + '&outFields=POP100%2C+HU100%2C+BLKGRP&returnGeometry=false'
      getString = getString + '&returnIdsOnly=false&returnCountOnly=false&returnZ=false&returnM=false&returnDistinctValues=false&f=pjson'
      # getString = getString + '?key=3ff5f0b1013cb070e057988b83453644ca198c34'
      # puts getString + " " + counter.to_s
      # puts ""

      threads[counter] = Thread.new {
        Thread.current["response"] = RestClient.get getString 
      }

      # 
      # The following sleep value determines the sleep time between each
      # threaded call to the Census Bureau's server.
      #
      sleep (0.1)

      counter = counter + 1
      n = n + 1
    end

    puts "Count: " + threads.length.to_s
    n = 0
puts "threads join"
    threads.join
puts 'threads combining'
    threads.each { |response| response.join }
puts "threads combined..."
    puts "============="
    threads.each do |response| 
        puts "thread " + n.to_s
        puts response["response"]
        hash = JSON.parse response["response"].to_s

        features = hash["features"];
        attributes = features[0];
        puts attributes

        tempPopulation = attributes["attributes"]["POP100"].to_f * block_group_overlap[n].to_f
        tempHousehold = attributes["attributes"]["HU100"].to_f * block_group_overlap[n].to_f
        puts ""
        puts tempPopulation
        puts tempHousehold
        totalPopulation = totalPopulation + tempPopulation
        totalHousehold = totalHousehold + tempHousehold 

        n = n + 1
    end

    nowTime = Time.now
    puts "Total Time: " + (nowTime - start).to_s
    puts "==============="
    puts "REST Calls: " + result.count.to_s
    puts "Avg REST Call: " + ((nowTime - start) / result.count).to_s
    puts "==============="
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
    # puts params[:polygon]

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
  end


end
