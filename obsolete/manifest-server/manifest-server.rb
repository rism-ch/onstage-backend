# myapp.rb
require 'sinatra'
require 'awesome_print'
require 'iiif/presentation'
require 'nokogiri'
require 'json'

include Update

configure do
  set :bind, '0.0.0.0'
end

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
TEI_PATH="path_to"
#IIF_PATH="https://iiif.rism-ch.org/iiif/"

def create_manifest(dir, images, title)
  
  # Create the base manifest file
  seed = {
      '@id' => "https://iiif.rism-ch.org/manifest/#{dir}.json",
      'label' => title,
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

    image_resource = IIIF::Presentation::ImageResource.create_image_api_image_resource(service_id: image_url)
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

  begin
    images = xml_file.xpath("//xmlns:p/xmlns:pb")
  rescue Nokogiri::XML::XPath::SyntaxError
    halt 500
  end

  files = images.each.collect {|t| t.attribute("facs").value.match(/([\w-]+(?:\.\w+)*$)/)[0]}
  path = images[0].attribute("facs").value.match(/(.*)\//)[0]

  return path, files
end

get '/manifest/:file' do
  dir, files = get_images(params[:file])
  
  if dir == nil
    halt 404
  end
  
  create_manifest(dir, files, params[:file].chomp(".xml"))
end

get '/solr_status' do
  return get_solr_status.to_json
end

not_found do
  'Resouce not found.'
end


# Courtsy of GitHib!
def verify_signature(request)
  secret_token = "Put_a_secret_token_here"
  request.body.rewind
  payload_body = request.body.read
  signature = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), secret_token, payload_body)
  return Rack::Utils.secure_compare(signature, request.env['HTTP_X_HUB_SIGNATURE'])
end

post '/update' do

  if !verify_signature(request)
    halt 500  , "Invalid signature"
  end

  event = request.env['HTTP_X_GITHUB_EVENT']
  request.body.rewind

  case event
  when 'push'
    payload = JSON.parse(request.body.read)
    repo = payload['repository']['full_name']
    user = payload['sender']['login']
    user_url = payload['sender']['html_url']
    puts "This is a push event on '#{repo}' by '#{user}': #{user_url}"

    # Do the maintainance operations
    update_index
  else
    puts "Unmanaged '#{event}'"
  end
end