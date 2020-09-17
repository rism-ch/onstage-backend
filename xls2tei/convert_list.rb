require "csv"
require "awesome_print"
require 'nokogiri'
require "rexml/document" 

# Make empty files
# find . -name "*.tif" -print0 | xargs -0 -I, touch ../empty_files/,
# This is handy to get the filenames of the images without the image
# so the directory listing is easy to work on

# Rename OCR output
# find . -name "*.txt" -print | sed 'p;s/.tif.txt.txt/.txt/g' | xargs -n2 mv

# run tessarect
# find . -name bmu_\* -print | while read filename; do tesseract $filename $filename.txt -l fra; done

headers = [
    :cote,
    :file_names,
    :saison,
    :date,
    :collation,
    :place,
    :title,
    :composers,
    :interpreters,
    :serie,
    :notes
]

RISM_PEOPLE_URL = "https://muscat.rism.info/admin/people/"

IMAGE_DIR="empty_files"
OCR_DIR="ocr_output"
OUTPUT_DIR="tei_output"

def unpack_names(composer_list, type)
    return "" if ! composer_list
    lines = []

    composer_list.split(";").each do |composer_line|
        composer_line.strip!

        matches = composer_line.match /\{(.*?)\}/
        if matches
            sigla, id = matches[1].split(":") # 1 element is withut brackets
            name = composer_line.sub(matches[0], '') # note the 0 elements is with brackes
            name.strip!
            name.tr!('"', '')

            if sigla == "RISM"
                ref = "ref=\"#{RISM_PEOPLE_URL}#{id}\""
            end

            #puts "<name key=\"#{name}\" #{ref} type=\"person\" role=\"cmp\">#{name}</name>"
        else
            name = composer_line.strip.tr('"', '')
        end

        lines << "<name key=\"#{name}\" #{ref} type=\"person\" role=\"#{type}\">#{name}</name>"
    end

    lines
end

def find_images(entry)
    pages = []
    Dir.glob(IMAGE_DIR + "/#{entry.downcase}*").each do |image_name|
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

        content = "<pb facs=\"CH_Gmu_prg/pyr_#{name}\"/>\n"
        content += "<page>#{page_cdata}</page>"

        pages << content
    end
    pages
end

def make_date_when(date)
    dates = []
    dates_long = []

    dates = ""
    dates_long = ""
    date.split(";").each do |d|
        code = d.strip.tr('\[\]\-\?\.', '').rjust(8, '0')
        dates +=  "<date when=\"#{code}\"/>\n"

        long_date = "#{code[6, 2]}/#{code[4, 2]}/#{code[0, 4]}"
        dates_long +=  "<date when=\"#{long_date}\"/>"
    end

    return dates, dates_long
end

def split_notes(notes)
    return "" if notes == nil || notes.empty?

    xml = ""
    notes.split(";").each do |n|
        next if n.strip.empty?
        xml += "<note>#{n.strip}</note>\n"
    end

    return xml
end

def split_place(place, key=false)
    return "" if place == nil || place.empty?

    xml = ""
    place.split(";").each do |n|
        if key
            xml += "<placeName key=\"#{n.strip.gsub(';', '')}\" />\n"
        else
            xml += "<placeName>#{n.strip.gsub(';', '')}</placeName>\n"
        end
    end

    return xml
end

@template = File.open("tei_template.xml", "r:UTF-8", &:read)
CSV::foreach("example_data.csv", col_sep: "\t", headers: headers) do |r|

    composer_lines = unpack_names(r[:composers], "cmp")
    interpreter_lines = unpack_names(r[:interpreters], "int")

    pages = find_images(r[:file_names])
    dates, dates_long = make_date_when(r[:date])
    
    title = r[:title] ? r[:title].strip.gsub("\n", "") : "[sans titre]"

    # Start buinding the Source Description
    srcdesc = "<title>#{title}#{dates_long}</title>\n"
    srcdesc += "<series>#{r[:saison]}</series>\n"
    #srcdesc += "<placeName>#{r[:place]}</placeName>\n"
    srcdesc += split_place(r[:place])
    srcdesc += "<orgName role=\"holding\">Bibliothèque du Conservatoire de Musique de Genève; <link target=\"http://www.cmusge.ch/contact_bibliotheque\"/></orgName>\n"
    srcdesc += "<idno>#{r[:cote]}</idno>\n"
  
    # Now build the content
    content = dates
    content += "<title>#{title}</title>\n" if r[:title]
    content += split_place(r[:place], true) # different in here!
    content += "<name key=\"#{r[:saison]}\" type=\"series\"/>\n" if r[:saison]

    content += composer_lines.join("\n") + "\n" if !composer_lines.empty?
    content += interpreter_lines.join("\n") + "\n"  if !interpreter_lines.empty?

    content += pages.join("\n")

    # Finally the notes
    notes = split_notes(r[:notes])

    final_xml = @template.gsub(/\$\$SRCDESC\$\$\$/, srcdesc)
    final_xml = final_xml.gsub(/\$\$NOTES\$\$/, notes)
    final_xml = final_xml.gsub(/\$\$CONTENT\$\$/, content)

    # Make a nice formatted version of the xml
    formatted_xml = ""
    doc = REXML::Document.new(final_xml)
    formatter = REXML::Formatters::Pretty.new
    
    # Compact uses as little whitespace as possible
    formatter.compact = true
    formatter.width = 20000
    formatter.write(doc, formatted_xml)

    # Commit to file
    File.open(OUTPUT_DIR + "/#{r[:file_names].downcase}.xml", 'w') do |outf|
        outf.write(formatted_xml)
    end


end
