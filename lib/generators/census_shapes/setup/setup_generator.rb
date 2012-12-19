require 'rails/generators/migration'

module CensusShapes
  module Generators
    class SetupGenerator < ::Rails::Generators::Base

      include Rails::Generators::Migration       
      source_root File.expand_path('../templates', __FILE__)
      
      argument :name, :type => :string, :default => "geography"
    
      class_option :route, :type => :boolean, :default => true, :description => "Generate Route" 
      class_option :model, :type => :boolean, :default => true, :description => "Generate Model"
      class_option :controller, :type => :boolean, :default => true, :description => "Generate Controller"  
      class_option :view, :type => :boolean, :default => true, :description => "Generate View"  
    
      desc "add gem dependencies"
      def add_gems
        gem("pg")
        gem("postgis_adapter")
      end

      desc "add the geographies migration"
      def self.next_migration_number(path)
        unless @prev_migration_nr
          @prev_migration_nr = Time.now.utc.strftime("%Y%m%d%H%M%S").to_i
        else
          @prev_migration_nr += 1
        end
        @prev_migration_nr.to_s
      end

      def copy_files
        migration_template "db/migrate/create_shapes.rb", "db/migrate/create_#{controller_name}.rb", {:controller_name => controller_name }
        copy_file "config/database_example.yml", "config/database_example.yml"
        copy_file "lib/tasks/postgis_template.rake", "lib/tasks/postgis_template.rake"
        copy_file "lib/tasks/census_shapes.rake", "lib/tasks/census_shapes.rake"
        gsub_file "lib/tasks/census_shapes.rake", "CONTROLLER_NAME", controller_name
        copy_file "lib/yaml/us_shapes.yml", "lib/yaml/us_shapes.yml"
        copy_file "lib/yaml/us_states.yml", "lib/yaml/us_states.yml"
        copy_file "config/initializers/shapes_globals.rb", "config/initializers/#{controller_name}_globals.rb"
        gsub_file "config/initializers/#{controller_name}_globals.rb", "MODEL_NAME", model_name
      end
    
      def add_geographies_route
        if options.route
          route("resources :#{model_name}")
          route("match ':type/:z/:x/:y.:format'=> '#{controller_name}#index', :requirements => {:z => /-?\d+(\.\d+)/, :x => /-?\d+(\.\d+)/, :y => /-?\d+(\.\d+)/ }")
          route("root :to => '#{controller_name}#index'")
        end
      end
    
      def add_model
        if options.model
          copy_file "models/shape.rb", "app/models/#{model_name}.rb"
          gsub_file "app/models/#{model_name}.rb", "MODEL_NAME", model_name
        end
      end

      def add_controller
        if options.controller
          copy_file "controllers/shapes_controller.rb", "app/controllers/#{controller_name}_controller.rb"
          gsub_file "app/controllers/#{controller_name.underscore}_controller.rb", "CONTROLLER_NAME", controller_name.camelcase
          gsub_file "app/controllers/#{controller_name.underscore}_controller.rb", "MODEL_NAME", model_name
        end
      end
    
      def add_views
        if options.view
          copy_file "views/layouts/shapes.html.erb", "app/views/layouts/#{controller_name.underscore}.html.erb"
          directory "views/shapes", "app/views/#{controller_name.underscore}"
          gsub_file "app/views/#{controller_name.underscore}/index.html.erb", "MODEL_NAME", model_name
          gsub_file "app/views/#{controller_name.underscore}/index.html.erb", "MODEL_DOWNCASE", model_name.downcase
          gsub_file "app/views/#{controller_name.underscore}/index.html.erb", "CONTROLLER_NAME", controller_name
        end
      end

      def remove_public_index
        `rm public/index.html`
      end

      private
    
      def model_name  
        name.classify
      end
      
      def controller_name
        name.tableize
      end
    end
    
    class String
      
      def underscore
        self.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr("-", "_").
        downcase
      end
    end
  end
end