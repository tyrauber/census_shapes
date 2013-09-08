require 'net/ftp'
require 'yaml'
require 'progress_bar'

CONFIG = YAML::load(File.open('config/database.yml'))
DB = CONFIG[Rails.env]['database']
USER = CONFIG[Rails.env]['username']
HOST = CONFIG[Rails.env]['host']
TEMPLATE = CONFIG[Rails.env]['template']

namespace :census_shapes do
  desc "Import Census Shapes" 
  task :import  => :environment do
    if local_path(ENV['FILEPATH'])
      for geo in format_args(ENV['SHAPE'], msg('install'))
        before_import_set_defaults(geo)
        puts "Importing Census Shape #{geo['name']} (#{geo['slug']})"
        @dbar = ProgressBar.new(52)
        for state in CENSUS_STATES
          path = "#{CENSUS_SHAPES_PATH}/#{geo['path']}/"
          file = "tl_2010_#{state[1]["id"].to_s.rjust(2,'0')}_#{geo['slug'].downcase}10"
          download_zip(path, file, geo['slug'])
          unzip_shapefiles(file, geo['slug'])
          import_shapefiles(file, geo['slug'], ENV['ARCHIVE'])
          @dbar.increment!
        end
        after_import_update_fields
      end
    end
  end

  desc "Validate Geometry"
  task :validate_geometry => :environment do
    @dbar = ProgressBar.new(Geography.count)
    Geography.find_in_batches(:select=> "gid, geoid10, type, ST_IsValid(geom) AS isvalid", :batch_size => 100) do |batch|
      batch.each do |geo|
        if geo['isvalid'] == 'f';
          puts "Geography #{geo['type']} : gid = #{geo['gid']}, geoid10 = #{geo['geoid10']} is #{geo['isvalid']}"
          ActiveRecord::Base.connection.execute("UPDATE CONTROLLER_NAME SET geom = '#{geo.fix_geometry['geo']}' WHERE geoid10 = '#{geo.geoid10}' AND type = '#{geo.type}'")
          puts "Geography fixed? #{ActiveRecord::Base.connection.execute("SELECT ST_IsValid(geom) AS isvalid FROM Geographies WHERE geoid10 = '#{geo.geoid10}' AND type = '#{geo.type}'").first['isvalid'] == 't'}"
        end
        @dbar.increment!
      end
    end
  end

  desc "Repair Geometry"
  task :repair_geometry => :environment do
    for geo in format_args(ENV['SHAPE'], msg('repair'))
      @dbar = ProgressBar.new(Geography.where(:type=> geo['slug'].capitalize).count)
      Geography.find_in_batches(:select=> "gid, geoid10, name10, type, latlng, ST_AsText(geom) AS geo", :conditions => {:type => geo['slug'].capitalize}, :batch_size => 100) do |batch|
        batch.each do |b|
          rebuild = false
          ids = ActiveRecord::Base.connection.execute("SELECT c.geoid10 FROM CONTROLLER_NAME AS p, CONTROLLER_NAME AS c WHERE c.geoid10 != '#{b.geoid10}' AND p.geoid10 = '#{b.geoid10}' AND c.type='#{b.type}' AND ST_DWithin(p.latlng, c.latlng, .5);").map{|id| id['geoid10']}
          if !ids.empty?
            intersects = Geography.where("geoid10 IN ('#{ids.join("','")}') AND type = '#{b.type}' AND ST_Intersects('#{b['geo']}', geom)")
            if !intersects.empty?
              polygons = b.polygons
              intersects.each do |int| 
                int.polygons.each_with_index do |c, i|
                  current = ActiveRecord::Base.connection.execute("SELECT ST_Within('#{c}','#{b['geo']}') AS within").first
                  if !polygons.include?(c) && current['within'] == "t"
                    match = ActiveRecord::Base.connection.execute("SELECT #{polygons.map.with_index{|p, i| "ST_Intersects('#{p}', '#{c}') AS poly_#{i}"}.join(",")}").first.values.map{|aa| aa == "t" }
                    if !match.include?(true)
                      polygons << c
                      rebuild = true
                      puts "#{b.type} #{b.geoid10} has children #{int.geoid10}"
                    end
                  end
                end
              end
              if rebuild
                new_geom = Geography.merge(polygons)
                if new_geom['isvalid']
                  ActiveRecord::Base.connection.execute("UPDATE CONTROLLER_NAME SET geom = '#{new_geom['geom']}' WHERE geoid10 = '#{b.geoid10}' AND type = '#{b.type}'")
                else
                  ActiveRecord::Base.connection.execute("UPDATE CONTROLLER_NAME SET geom = ST_Buffer('#{new_geom['geom']}', .0000001) WHERE geoid10 = '#{b.geoid10}' AND type = '#{b.type}'")                
                end
              end
            end
          end
          @dbar.increment!
        end
      end
    end
  end

  def msg(type)
    msg = "\nPlease specify one or more of the following Census shapes:\n\n"
    msg += "#{CENSUS_SHAPES.map{|g| g[0]}.join(",")}\n\n"
    if type == "install"
      msg += "For example: rake census_shapes:install SHAPE=STATE,COUNTY\n\n"
      msg += "Add the option 'ARCHIVE=true' to archive the zip files after importing."
    elsif type== "validate"
      msg += "For example: rake census_shapes:validate_geometry SHAPE=STATE,COUNTY\n\n"
    elsif type== "repair"
      msg += "For example: rake census_shapes:repair_geometry SHAPE=STATE,COUNTY\n\n"
    end
    return msg
  end

  def format_args(args, msg)
    geos = []
    if args.nil?
      puts msg
    else
      args = args.split(",")
      for arg in args
        g = get_levels(arg.upcase)
        geos << g if g
      end
    end
    return geos
  end

  def get_levels(level)
    if !level.nil? && CENSUS_SHAPES.include?(level.upcase)
      return CENSUS_SHAPES[level] 
    else
      return false
    end
  end
  
  def local_path(local="tmp/shapefiles/")
    return @local if @local
    `mkdir -p #{local}`
    if !File.exists?(local) && !File.directory?(local)
      puts "'#{local}' is not a valid file path."
      return false
    end
    @local = local
    return @local
  end

  def download_zip(path, file, shape)
    if !File.exist?("#{local_path}#{shape}/#{file}.zip") 
      `mkdir -p #{local_path}#{shape}`
      ftp = Net::FTP.new(CENSUS_HOST)
      ftp.passive = true
      ftp.login(user = "anonymous")
      ftp.chdir(path)
      ftp.getbinaryfile("#{file}.zip", "#{local_path}#{shape}/#{file}.zip")
      ftp.close
    end
  end

  def self.unzip_shapefiles(file, shape)
    `unzip #{local_path}#{shape}/#{file}.zip -d #{local_path}#{shape}/#{file}` if File.exist?("#{local_path}#{shape}/#{file}.zip") 
  end

  def self.import_shapefiles(file, shape, archive)
    `shp2pgsql -W Latin1 -g geom -a -D #{local_path}#{shape}/#{file}/#{file} CONTROLLER_NAME #{TEMPLATE} | psql -h #{HOST} -U #{USER} -d #{DB}`
    `rm -rf #{local_path}#{shape}/#{file}`
    if archive.nil?
      `rm #{local_path}#{shape}/#{file}.zip`
    end
  end
 
  def before_import_set_defaults(geo)
    ActiveRecord::Base.connection.execute("ALTER TABLE ONLY CONTROLLER_NAME ALTER COLUMN type SET DEFAULT '#{geo['slug'].capitalize}'")
    ActiveRecord::Base.connection.execute("ALTER TABLE ONLY CONTROLLER_NAME ALTER COLUMN sumlevel SET DEFAULT '#{geo['sumlevel']}'")
  end

  def after_import_update_fields
    ActiveRecord::Base.connection.execute("UPDATE CONTROLLER_NAME SET latlng = ST_GeomFromText('POINT(' || intptlon10 || ' ' ||  intptlat10 || ')', 4326) WHERE latlng IS NULL;")
    ActiveRecord::Base.connection.execute("UPDATE CONTROLLER_NAME SET name10 = namelsad10 WHERE namelsad10 IS NOT NULL AND name10 IS NULL;")
  end
end
