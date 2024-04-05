# encoding: utf-8
require 'csv'
#require 'iconv'
require 'ap'
require 'nokogiri'
require "rexml/document" 

@substitutions = Hash.new
@template = nil
@irreversible_names = []
@install_date_cache = [] # Save the dates as a map for the installer later on

def sanitize(str)
  return nil if str == nil
  return str.gsub("<", "&lt;").gsub("&", "&amp;").gsub(">", "&gt;").gsub("\"", "&quot;").gsub("'", "&apos;")
end

OCR_DIR="ocr_output"
def find_ocr(image_name)
    pages = []

      fulltext = ""
      name_no_ext = File.basename(image_name, ".tif")
      name = File.basename(image_name)

      if !File.exist?(OCR_DIR + "/#{name_no_ext}.txt")
          puts name_no_ext.red
      else
          fulltext = File.read(OCR_DIR + "/#{name_no_ext}.txt").encode('UTF-8', :invalid => :replace, :undef => :replace).strip
      end

      # Strip all empty or whitespace lines
      fulltext = fulltext.gsub(/^$\n/, '')
      fulltext_strip = ""
      fulltext.each_line do |l|
          l = l.strip
          l = l.gsub(/^$\n/, '')
          next if l.empty?
          fulltext_strip += l + "\n"
      end

      # Create the CDATA element
      tmp = Nokogiri::XML::Document.new
      page_cdata = tmp.create_cdata(fulltext_strip)

      content = "<page>#{page_cdata}</page>"

      content

end

def process_file(file)
  pages = {}
  current_page = nil
  
  CSV.foreach(file, :encoding => "UTF-8") do |row|
    
    # skip the first image
    next if row[0] == "line_no"
    
    hash_row = {
      line_no:  row[0],
      images:   row[1],
      doc_no:   row[2],
      type:     row[3],
      date:     row[4],
      place:    row[5],
      names_ens:  row[6],
      names_int:  row[7],
      names_comp: row[8]
    }

    if hash_row[:doc_no] != nil
      if current_page != nil
        
        current_page[:composers].compact!
        current_page[:interpreters].compact!
        current_page[:ensembles].compact!
        current_page[:subpages].compact!
        
        pages[current_page[:page]] = current_page
      end
      
      current_page = {
        dir: "CH_Bm_prg",
        page: hash_row[:images],
        date: hash_row[:date],
        index: hash_row[:doc_no],
        place: hash_row[:place],
        series: hash_row[:type],
        composers: [hash_row[:names_comp]],
        interpreters: [hash_row[:names_int]],
        ensembles: [hash_row[:names_ens]],
        subpages: []
      }
    else
      current_page[:composers] << hash_row[:names_comp] if hash_row[:names_comp]
      current_page[:interpreters] << hash_row[:names_int] if hash_row[:names_int]
      current_page[:ensembles] << hash_row[:names_ens] if hash_row[:names_ens]
      current_page[:subpages] << hash_row[:images] if hash_row[:images]
    end

#    entry = {
#      dir: "Gc_prg/#{p[0]}",
#      page: page,
#      date: row[1],
#      index: row[2].to_i,
#      idx: row[3],
#      content: sanitize(row[4]),
#      place: sanitize(row[5]),
#      organizer: sanitize(row[6]),
#      series: sanitize(row[7]),
#      note: sanitize(row[8]),
#      composers: composers
#    }
    

  end
  
  pages.each do |page, entry|

    # Date encoding is a mistery to manking
    # and to programmers in general
    # Case 1) multiple dates: 18600211; 18600218
    # Case 2) Incomplete dates: 1856----
    # Case 3) Good dates: 18610108
    dates = []

    # First, try to split on the semicolumn
    if entry[:date] == nil
      puts "#{file}"
      ap entry
      entry[:date] = "00000000"
    end
    t = entry[:date].split(";")
    if t.count > 0
      t.each do |tok|
        tok.strip!
      
        dates << {
          year: tok[0, 4],
          month: tok[4, 2],
          day: tok[6, 2],
          raw: tok
        }
      
      end
    else
      dates << {
        year: entry[:date][0, 4],
        month: entry[:date][4, 2],
        day: entry[:date][6, 2],
        raw: entry[:date].strip
      }
    end

    title = entry[:series]
    series = entry[:series] != nil ? entry[:series] : "None"

    # Make the source description
    srcdesc = "<title>#{title}<date when=\"#{dates.first[:raw]}\">#{dates.first[:day]}/#{dates.first[:month]}/#{dates.first[:year]}</date></title>\n"
    srcdesc += "<series>#{series}</series>\n"
    
    if entry[:place]
      p = @substitutions[entry[:place].downcase.strip]
      puts entry[:place].downcase.strip if p == nil
      p = entry[:place] if p == nil

      srcdesc += "<placeName>#{p}</placeName>\n"
    end
    # FIXME
    srcdesc += "<orgName role=\"holding\">Archiv des Vereins Freunde alter Musik Basel; <link target=\"http://famb.ch/\"/></orgName>\n"
  
    # Make the contents
    people = entry[:composers].map { |c|
      norm = @substitutions[c.downcase.strip]
      #puts c if norm == nil
      norm =  c if norm == nil

      "<name key=\"#{norm}\" type=\"person\" role=\"cmp\">#{c}</name>"
    }.join("\n")
  
    people += entry[:interpreters].map { |c|
      norm = @substitutions[c.downcase.strip]
      #puts c if norm == nil
      norm =  c if norm == nil

      "<name key=\"#{norm}\" type=\"person\" role=\"int\">#{c}</name>"
    }.join("\n")
  
    content = "<pb facs=\"#{entry[:dir]}/pyr_#{page}.tif\"/>\n"
    dates.each do |d|
      content += "<date when=\"#{d[:raw]}\"/>\n"
    end
    content += people
    content += "<title>#{title}</title>\n" if title
    content += "<placeName key=\"#{p}\"/>\n" if p
    content += "<name key=\"#{series}\" type=\"series\"/>\n" if series
    content += find_ocr("#{page}.tif") ###"<p>OCR/#{entry[:dir]}/#{page}.txt</p>\n"
  
    entry[:subpages].each do |subpage|
      content += "<pb facs=\"#{entry[:dir]}/pyr_#{subpage}.tif\"/>\n"
      content += find_ocr("#{subpage}.tif") ###"<p>#{subpage}.txt</p>\n"
    end
  
  
    final_xml = @template.gsub(/\$\$SRCDESC\$\$\$/, srcdesc)
    final_xml = final_xml.gsub(/\$\$CONTENT\$\$/, content)
 
    formatted_xml = ""
    doc = REXML::Document.new(final_xml)
    formatter = REXML::Formatters::Pretty.new

    formatter.compact = true
    formatter.width = 20000
    formatter.write(doc, formatted_xml)

    # Commit to file
    File.open("out/#{page}.xml", 'w') do |outf|
      outf.write(formatted_xml)
    end
  
    # Assume the same concert does not span two years
    # (new year's gala?)
    @install_date_cache << ["#{page}.txt", dates.first[:year]]
    entry[:subpages].each do |subpage|
      @install_date_cache << ["#{subpage}.txt", dates.first[:year]]
    end
  
  end
end

#@template = File.read('tei_template.xml', "r:UTF-8")
@template = File.open("tei_template.xml", "r:UTF-8", &:read)

CSV.foreach("norm.csv", :encoding => "UTF-8") do |row|
  
  if row[0] != nil
    @substitutions[row[0].downcase.strip] = row[1]
  end
  
end


process_file("index_FAMB_add_2023.csv")

# Cache names
puts @irreversible_names.sort.uniq.count

CSV.open("unique_names.csv", "wb") do |csv|
  csv << ["a", "b"]
  @irreversible_names.sort.uniq.each do |n|
    csv << [n, n]
  end
end

File.open("date_cache.txt", "w+") do |f|
  @install_date_cache.each { |dc| f.puts("#{dc[0]}\t#{dc[1]}") }
end