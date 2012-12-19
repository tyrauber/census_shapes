census_shapes
==================

A Ruby Gem that facilitates the importing US Census Shapefiles into a PostGIS database.

### Prerequisites

This gem requires Postgres / PostGIS and is intended to be used with a Rails 3 application.

### Installation

To install the 'census_shapes' ruby gem:

`gem install census_shapes`

To use the gem in your Rails 3 Application, include the gem in your Gemfile:

`gem "census_shapes"`

### SETUP

## 1) $ rails generate census_shapes:setup

To setup your rails application to use census_shapes, run the following generator:

`rails g census_shapes:setup MODEL_NAME`

This will create all the necessary files, including:

    config/database_example.yml
    db/###_create_geographies.rb
    lib/tasks/postgis_template.rake
    lib/tasks/census_shapes.rake
    
    app/models/geography.rb
    app/controllers/geographies_controller.rb
    app/views/layouts/geographies.html.erb
    app/assets/stylesheets/geographies.css.scss
    app/views/geographies/partials/_map.erb

## 2) Setup your Database

The generator will create an example database configuration file at: config/database_example.yml.

Edit the database, template, username and password values for your environment. Change the postgis_path for the appropriate environment(s). If you installed PostGIS through homebrew on OS X, the development path should be:  /usr/local/share/postgis/

Rename the file database.yml.

## 3) Create a PostGIS Template

In your application directory, run the following rake task from the command console:

`rake postgis_template:create`

The generator uses the values set in database.yml, including the postgis_path to find the necessary PostGIS SQL files, and will generate a template database if one does not already exist.

## 3) Migrate Database

If Postgres / PostGIS is setup properly and the database.yml and template database are configured, you should now be able to migrate the database:

`rake db:migrate`

## 4) Import Census Geographies

With the database migrated, we may import the census geographies:

`rake census_shapes:import SHAPE=DESIRED_SHAPES`

Replace DESIRED_SHAPES with the slugs of the Census Shapes you wish to import. For example, to import States and Counties, you would run the following command:

`rake census_shapes:import SHAPE=STATE,COUNTY`

The import process will download the zips of the required Census Shapes to 'tmp/shapefiles', unless a path is specified with the PATH argument:

`rake census_shapes:import SHAPE=STATE,COUNTY PATH=/usr/local/shapefiles`

Lastly, the Zip files will be deleted after import unless the ARCHIVE argument is specified:

`rake census_shapes:import SHAPE=STATE,COUNTY ARCHIVE=true`

For a full list of the 22 supported Census Geographic Summary Levels, see 'Summary Levels' of the 'Usage' section.

Note: Depending upon your internet speed and the amount of Census Shapes you require, this may take several hours or days to complete.

## 5) Validate Geometry (Optional)

Depending upon the Census Shapes you install, validation may be required. For example:

rake census_shapes:validate_geometry SHAPE=STATE,COUNTY

The validate_geometry rake task will test and repair the geometries of all imported shapes.

### USAGE

## Summary Levels

Census-Geographies will import the following 22 Geographic Summary Levels:

**Sumlevel - Slug:  Name**

 * 040 - STATE:  State
 * 050 - COUNTY:  County
 * 060 - COUSUB:  County Subdivision
 * 067 - SUBMCD:  Subminor Civil Subdivision
 * 101 - BLOCK:  Block
 * 140 - TRACT: Tract
 * 150 - BG:  Blockgroup
 * 160 - PLACE:  Place
 * 230 - ANRC: Alaska Native Regional Corporation
 * 280 - AIANNH: American Indian Area/Alaska Native Area/Hawaiian Home Land
 * 281 - AITS: American Indian Tribal Subdivision
 * 320 - CBSA:  Metropolitan Statistical Area/Micropolitan Statistical Area
 * 323 - METDIV: Metropolitan Division
 * 340 - CSA: Combined Statistical Area
 * 500 - CD: Congressional District (111th)
 * 610 - SLDU: State Legislative District (Upper Chamber)
 * 620 - SLDL:  State Legislative District (Lower Chamber)
 * 700 - VTD: Voting District
 * 871 - ZCTA5: ZIP Code Tabulation Area (5-Digit)
 * 950 - ELSD: School District (Elementary)
 * 960 - SCSD: School District (Secondary)
 * 970 - UNSD: School District (Unified)

