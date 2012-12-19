class MODEL_NAME < ActiveRecord::Base
  
  alias_attribute :id, :geoid10
  alias_attribute :name, :name10
  alias_attribute :region, :region10
  alias_attribute :division, :division10
  alias_attribute :state, :state10
  alias_attribute :statens, :statens10
  alias_attribute :statefp, :statefp10
  alias_attribute :countyfp, :countyfp10
  alias_attribute :tractce, :tractce10
  alias_attribute :blkgrpce, :blkgrpce10
  alias_attribute :stusps, :stusps10
  alias_attribute :lsad, :lsad10
  alias_attribute :mtcc10, :mtfcc10
  alias_attribute :funcstat, :funcstat10
  alias_attribute :land, :aland10
  alias_attribute :water, :awater10
  alias_attribute :lat, :intptlat10
  alias_attribute :lng, :intptlon10

  self.primary_key = :gid
  
  default_scope select("geoid10, name10, intptlat10, intptlon10, latlng, geom")

  def self.bbox(z,x,y)
    return false if z.nil? || x.nil? || y.nil?
    nw=coordinateLocation(z.to_i,x.to_i,y.to_i)
    se=coordinateLocation(z.to_i,x.to_i+1,y.to_i+1)
    return "#{nw[:lng]},#{se[:lat]},#{se[:lng]},#{nw[:lat]}"
  end
  
  def self.coordinateLocation(z,x,y)
    k = 45 / 2 ** (z - 3.001)
    return {:lng=> (k * x - 180).to_i,:lat=> y2lat(180 - k * y)}
  end

  def self.y2lat(y)
    return (360 / Math::PI * Math.atan(Math.exp(y * Math::PI / 180)) -90).round(2)
  end

  
  def self.features(options={})
    features = []; i =1; 
    options[:detail]=0.01 if options[:detail].nil?
    model = options[:type].capitalize.constantize
    if !options[:detail].nil?
      geos = model.select("name10, geoid10, ST_AsGeoJson(ST_SimplifyPreserveTopology(geom,#{options[:detail]})) AS geojson");
    else
      geos = model.select("name10, geoid10, ST_AsGeoJson(geom) As geojson, geom, ST_Area(geom) AS area, ST_IsValid(geom) AS isvalid");
    end
    if(options[:bbox])
      b = options[:bbox].split(",")
      ids = model.select("geoid10").where("ST_Contains(ST_AsText(ST_Envelope('LINESTRING(#{b[0]} #{b[1]},#{b[2]} #{b[3]})'::geometry)), ST_AsText(latlng))").map{|id| id['geoid10']}
      if options[:grid]
        geobox = model.select("ST_AsGeoJson(ST_Envelope('LINESTRING(#{b[0]} #{b[1]},#{b[2]} #{b[3]})'::geometry)) AS geojson").first
        features <<  {:type => "Feature", :geometry=> JSON.parse(geobox['geojson']), :properties => {:id=> "1", :name => "Box", :class=> 'box'}} 
      end
      if ids.empty?
        geos = []
      else
        geos = geos.where(:geoid10 => ids)
      end
    end
    if(options[:id])
       geos = geos.where(:geoid10=>options[:id].split(","))
    end
    for g in geos
      if g['isvalid'] != "t" && options[:fix_geom]
        new_g = g.fix_geometry
        msg = "Geometry invalid. Rebuilding. Original = #{g['isvalid'] == "t"}, Rebuilt Geometry = #{new_g['isvalid'] == "t"}, Old area (#{g['area']}) == New area (#{new_g['area']})"
        features <<  {:type => "Feature", :geometry=> JSON.parse(new_g['geojson']), :properties => {:id=> g.geoid10, :name => g.name10 }} 
      else
        features <<  {:type => "Feature", :geometry=> JSON.parse(g['geojson']), :properties => {:id=> g.geoid10, :name => g.name10 }} 
      end
      i=i+1
    end
    return features
  end
  
  def fix_geometry
    return self if self['isvalid'] == "t"
    rebuilt_g = MODEL_NAME.rebuild(self.polygons)
    return rebuilt_g if rebuilt_g['isvalid'] == "t"
    buffer_g = self.buffer
    return buffer_g if buffer_g['isvalid'] == "t"
    puts "ERROR GEOMETRY NOT FIXED"
    return false
  end
  
  def buffer
    return self.class.name.constantize.select("geoid10, ST_Buffer(geom,.000001) AS geo, ST_AsGeoJson(ST_Buffer(geom,.000001)) AS geojson, ST_IsValid(ST_Buffer(geom,.000001)) AS isvalid, ST_Area(ST_Buffer(geom,.000001)) AS area").where(:geoid10 => self.geoid10).first
  end
  
  def polygons
     return self.class.name.constantize.select("ST_AsText((ST_DumpRings(((ST_Dump(geom)).geom))).geom) AS g").where(:geoid10 => self.geoid10).map{|p| p['g'] }
  end
  
  def self.sort(polygons)
    return polygons.map{|p| 
      pp = ActiveRecord::Base.connection.execute("SELECT ST_Area('#{p}'), ST_AsText('#{p}') AS geo").first
      [pp['st_area'].to_f, pp['geo'] ]}.sort {|a, b| a[0] <=> b[0]}.reverse.map{|p| p[1]
    }
  end
  
  def self.rebuild(polygons)
    polygons = MODEL_NAME.sort(polygons)
    polygons.reverse.each do |p1|
      polygons.each do |p2|
         if p1 != p2 && ActiveRecord::Base.connection.execute("SELECT ST_Contains('#{p1}', '#{p2}') AS contains").first['contains'] == "t"
          temp = ActiveRecord::Base.connection.execute("SELECT ST_AsText(ST_Difference('#{p1}', '#{p2}')) AS union")
          polygons.delete(p1); polygons.delete(p2)
          polygons << temp.first['union']
        end
      end
    end
    polygons = MODEL_NAME.merge(polygons)
    return polygons
  end
  
  def self.merge(polygons)
    if polygons.count == 1
      return polygons[0]
    else
      array = polygons.map { |p| "ST_GeomFromText('#{p}')" }
      geo = ActiveRecord::Base.connection.execute("SELECT ST_Collect(ARRAY[#{array.join(',')}]) AS geo").first['geo']
      sql = "SELECT '#{geo}' AS geo, ST_AsGeoJson('#{geo}') AS geojson, ST_Area('#{geo}') AS area, ST_IsValid('#{geo}') AS isvalid;"
      return ActiveRecord::Base.connection.execute(sql).first
    end
  end
  
  def self.available_shapes
    return @available_shapes if @available_shapes
    @available_shapes = CENSUS_SHAPES
    available_types = MODEL_NAME.unscoped.select("DISTINCT(type)").map{|k,v| k['type'].upcase}
    @available_shapes.each do |k,v|
      @available_shapes.delete(k) if !available_types.include?(k)
    end
    return @available_shapes
  end
end

class State < MODEL_NAME; end
class County < MODEL_NAME; end
class Cousub < MODEL_NAME; end
class Submcd < MODEL_NAME; end
class Block < MODEL_NAME; end
class Tract < MODEL_NAME; end
class BG < MODEL_NAME; end
class Place < MODEL_NAME; end
class Anrc < MODEL_NAME; end
class Aiannh < MODEL_NAME; end
class Aits < MODEL_NAME; end
class Cbsa < MODEL_NAME; end
class Metdiv < MODEL_NAME; end
class Csa < MODEL_NAME; end
class Cd < MODEL_NAME; end
class Sldu < MODEL_NAME; end
class Sldl < MODEL_NAME; end
class Vtd < MODEL_NAME; end
class Zcta5 < MODEL_NAME; end
class Elsd < MODEL_NAME; end
class Scsd < MODEL_NAME; end
class Unsd < MODEL_NAME; end