class CONTROLLER_NAMEController < ApplicationController

  def index
    bbox = MODEL_NAME.bbox(params[:z],params[:x], params[:y])
    params.merge!(:bbox=> bbox) if bbox
    respond_to do |format|
      format.html
      format.json  {
        render json: ({
          :status=> "OK",
          :type => "FeatureCollection",
          :features=> MODEL_NAME.features(params)
        })
      }
    end
  end
end