require 'rest-client'
require 'pg'
require 'rgeo/geo_json'
require 'json'

class MapController < ApplicationController
  def show_map
    # puts ("trace")
  end

  def insert_iso_shape
    conn = PGconn.open(
      :host => 'aws-gis.cot74qrzzmqu.us-west-2.rds.amazonaws.com',
      :port => 5432,
      :dbname => 'awsgis',
      :user => 'master',
      :password => 'mastermaster')

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

    row = result.first
    rowID = row['id']
    puts rowID


    selectString = 'select geoid10 as block_group_id, (st_area(st_intersection(user_polygons.geom, bg_2010.geom))/st_area(bg_2010.geom)) as user_polygon_percent_overlap from bg_2010, user_polygons where user_polygons.id = $1 and ST_INTERSECTS(user_polygons.geom, bg_2010.geom) order by geoid10;'
    result = conn.query(selectString, [rowID])
    
    block_group_id = Array.new
    block_group_overlap = Array.new

    result.each do |row|
      #puts row['block_group_id'] + "    " + row['user_polygon_percent_overlap']
      block_group_id.push(row['block_group_id'])
      block_group_overlap.push(row['user_polygon_percent_overlap'])
    end

    n = 0
    while (n < block_group_id.length) do
      puts block_group_id[n] + "   " + block_group_overlap[n]
      n = n + 1
    end 

    render :json => {
      connection: row['id']
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
