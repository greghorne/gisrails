require 'rest-client'
require 'pg'
require 'rgeo/geo_json'
require 'json'
require 'eventmachine'

class MapController < ApplicationController

  def show_map

  end


  def insert_iso_shape
    conn = PGconn.open(
      :host => 'aws-gis.cot74qrzzmqu.us-west-2.rds.amazonaws.com',
      :dbname => 'awsgis',
      :port => 5432,
      :user => 'master',
      :password => 'mastermaster')

    ########################################################
    # having to strip some characters from GeoJSON string prior
    # to insert into DB
    #
    polygon = params[:polygon].to_json()

    polygon = polygon.gsub("\\", "")
    polygon.chop!
    polygon[0] = ''

    insertString = 'insert into user_polygons (name, geom) VALUES ($1, ST_SetSRID(ST_GeomFromGeoJSON($2), 4269)) RETURNING id'
    result = conn.query(insertString, ['Test Insert', polygon])

    row = result.first
    rowID = row['id']

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
