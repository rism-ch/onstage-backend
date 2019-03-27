require 'nokogiri'

def insert_txt_file(orig_file_name)
  puts "Processing #{orig_file_name}"
  
  xml_file = Nokogiri::XML(File.open(orig_file_name))

  date = xml_file.xpath("/xmlns:TEI/xmlns:teiHeader/xmlns:fileDesc/xmlns:sourceDesc/xmlns:bibl/xmlns:title/xmlns:date/@when").first.content.match(/(^[0-9]{4})/)

  txt = xml_file.xpath("//xmlns:p/xmlns:p")

  txt.each do |t|
    file_name =  t.content.match(/([\w-]+(?:\.\w+)*$)/)
    text = File.read("onstage-fulltext/#{date}-#{file_name}").encode('UTF-8', :invalid => :replace, :undef => :replace)
  
    tmp = Nokogiri::XML::Document.new
    t.add_next_sibling("<page>#{tmp.create_cdata(text)}</page>")
  
    t.unlink
  end
  
  File.write(orig_file_name, xml_file.to_xml)
  
end

Dir["/Users/xhero/TEI-transform/*.xml"].each {|file| insert_txt_file(file)}