class Create<%= controller_name.titleize.gsub(' ', '').gsub(/\W/,'') %> < ActiveRecord::Migration
  def up
    create_table(:<%= controller_name %>) do |t|
        t.string :type, :limit => 12
        t.string :sumlevel, :limit => 3
        t.string :geoid10, :limit => 15
        t.string :name10, :limit => 100
        t.string :namelsad10, :limit => 100
        t.string :region10, :limit => 2
        t.string :division10, :limit => 2
        t.string :state10, :limit => 2
        t.string :statens10, :limit => 8
        t.string :statefp10, :limit => 2
        t.string :zcta5ce10, :limit => 5
        t.string :countyfp10, :limit => 3
        t.string :countyns10, :limit => 8
        t.string :cousubfp10, :limit => 5
        t.string :cousubns10, :limit => 8
        t.string :submcdfp10, :limit => 5
        t.string :submcdns10, :limit => 8
        t.string :tractce10, :limit => 6
        t.string :blockce10, :limit => 4
        t.string :blkgrpce10, :limit => 6
        t.string :placefp10, :limit => 5
        t.string :placens10, :limit => 8
        t.string :csafp10, :limit => 3
        t.string :cbsafp10, :limit => 5
        t.string :metdivfp10, :limit => 5
        t.string :cd111fp, :limit => 2
        t.string :cdsessn, :limit => 3
        t.string :anrcfp10, :limit => 5
        t.string :anrcns10, :limit => 8
        t.string :aiannhce10, :limit => 4
        t.string :aiannhns10, :limit => 8
        t.string :trsubce10, :limit => 3
        t.string :trsubns10, :limit => 8
        t.string :sldust10, :limit => 3
        t.string :sldlst10, :limit => 3
        t.string :vtdst10, :limit => 6
        t.string :elsdlea10, :limit => 5
        t.string :scsdlea10, :limit => 5
        t.string :unsdlea10, :limit => 5
        t.string :stusps10, :limit => 2
        t.string :lsad10, :limit => 2
        t.string :lsy10, :limit=> 4
        t.string :lograde10, :limit => 2
        t.string :higrade10, :limit => 2
        t.string :sdtyp10, :limigt => 1
        t.string :classfp10, :limit => 2
        t.string :comptyp10, :limit => 1
        t.string :aiannhr10, :limit => 1
        t.string :aiannhfp10, :limit => 5
        t.string :trsubfp10, :limit => 5
        t.string :partflg10, :limit => 1
        t.string :pcicbsa10, :limit => 1
        t.string :pcinecta10, :limit => 1
        t.string :mtfcc10, :limit => 5
        t.string :memi10, :limit => 1
        t.string :ur10, :limit => 1
        t.string :uace10, :limit => 1
        t.string :uatyp10, :limit => 1
        t.string :vtdi10, :limit => 1
        t.string :cnectafp10, :limit => 3
        t.string :nectafp10, :limit => 5
        t.string :nctadvfp10, :limit => 5
        t.string :funcstat10, :limit => 1
        t.float :aland10, :length => 8
        t.float :awater10,  :length => 8
        t.point :latlng, :srid=> 4326
        t.geometry :geom, :srid=> 4326
        t.decimal :intptlat10, :precision => 15, :scale => 12
        t.decimal :intptlon10, :precision => 15, :scale => 12 
    end
    add_index :<%= controller_name %>, [:type,:geoid10], :name => "geo_index", :unique=> true
    execute "ALTER TABLE <%= controller_name %> RENAME COLUMN id TO gid;"
    execute "CREATE INDEX b_point ON <%= controller_name %> USING GIST (latlng);";
    execute "CREATE INDEX b_geom ON <%= controller_name %> USING GIST (geom);";
  end
  
  def down
    drop_table :<%= controller_name %>
  end
end



