# myapp.rb
require 'sinatra'
require 'awesome_print'
require 'iiif/presentation'
require 'nokogiri'


# WHY THE DEFAULS ARE ASININE??????
# This fixes an encoding issue with certain requests
module Faraday
  module NestedParamsEncoder
    def self.escape(arg)
			#puts "NOTICE - UNESCAPED URL NestedParamsEncoder"
      arg
    end
  end
  module FlatParamsEncoder
    def self.escape(arg)
			#puts "NOTICE - UNESCAPED URL FlatParamsEncoder"
      arg
    end
  end
end

IIF_PATH="http://d-lib.rism-ch.org/cgi-bin/iipsrv.fcgi?IIIF=/usr/local/images/raw/lausanne/"
TEI_PATH="/Users/xhero/TEI-transform"
#IIF_PATH="https://iiif.rism-ch.org/iiif/"

def create_manifest(dir, images)
  
  # Create the base manifest file
  seed = {
      '@id' => "https://iiif.rism-ch.org/manifest/#{dir}.json",
      'label' => dir,
      'related' => "http://www.rism-ch.org/catalog/#{dir}"
  }
  # Any options you add are added to the object
  manifest = IIIF::Presentation::Manifest.new(seed)
  sequence = IIIF::Presentation::Sequence.new
  manifest.sequences << sequence

  images.each do |image_name|
    canvas = IIIF::Presentation::Canvas.new()
    canvas['@id'] = "#{dir}/#{image_name}"
    canvas.label = image_name
  
    image_url = IIF_PATH + dir + "/" + image_name

    image = IIIF::Presentation::Annotation.new
    image["on"] = canvas['@id']
    ## Uncomment these two prints to see the progress of the HTTP reqs.
    #print "-"
    image_resource = IIIF::Presentation::ImageResource.create_image_api_image_resource(service_id: image_url)
    #print "."
    image.resource = image_resource
  
    canvas.width = image.resource['width']
    canvas.height = image.resource['height']
  
    canvas.images << image
    sequence.canvases << canvas
  
    # Some obnoxious servers block you after some requests
    # may also be a server/firewall combination
    # comment this if you are positive your server works
    #sleep 0.1
  end
  return manifest.to_json(pretty: true)
  
end

def get_images(xml_file)
  begin
    xml_file = Nokogiri::XML(File.open(TEI_PATH + "/" + xml_file))
  rescue Errno::ENOENT
    return nil, nil
  end

  images = xml_file.xpath("//xmlns:p/xmlns:pb")

  files = images.each.collect {|t| t.attribute("facs").value.match(/([\w-]+(?:\.\w+)*$)/)[0]}
  path = images[0].attribute("facs").value.match(/(.*)\//)[0]

  return path, files
end

get '/manifest/:file' do
  dir, files = get_images(params[:file])
  
  if dir == nil
    halt 404
  end
  
  create_manifest(dir, files)
end

not_found do
  'This is nowhere to be found.'
end
