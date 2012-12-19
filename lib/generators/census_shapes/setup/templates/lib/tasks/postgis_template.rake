namespace :postgis_template do
  desc "Creates Postgis Template"
	task :create do
	  config = YAML::load(File.open('config/database.yml'))
    template = config[Rails.env]['template']
    user = config[Rails.env]['username']
    host = config[Rails.env]['host']
    postgis_path = config[Rails.env]['postgis_path']
    
    existing = `psql -U #{user} -h #{host} -U #{user} --list`
    if existing.scan(template).empty?
  	  `createdb -U #{user} #{template} -h #{host} -U #{user} -E UTF8`
      `createlang -d #{template} plpgsql -h #{host} -U #{user}`
      `psql -d postgres -c "UPDATE pg_database SET datistemplate='true' WHERE datname='#{template}';"`
  	  `psql -h #{host} -U #{user} -d #{template} -f #{postgis_path}postgis.sql`
  	  `psql -h #{host} -U #{user} -d #{template} -f #{postgis_path}spatial_ref_sys.sql`
      `psql -d #{template} -c "GRANT ALL ON geometry_columns TO PUBLIC;"`
      `psql -d #{template} -c "GRANT ALL ON geography_columns TO PUBLIC;"` 
      `psql -d #{template} -c "GRANT ALL ON spatial_ref_sys TO PUBLIC;"`
	  end
  end
end