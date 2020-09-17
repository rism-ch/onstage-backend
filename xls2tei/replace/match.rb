require "csv"
require "awesome_print"
require "rexml/document" 
include REXML

files = Dir.glob('tei_output/**/*.xml')

titles = {}

composers = []
interpreters = []
professors = []
other = []
places = []
series = []
titles = []

CSV::foreach("names.csv", col_sep: "\t") do |r|
    composers << r
end

CSV::foreach("interpreters.csv", col_sep: "\t") do |r|
    interpreters << r
end

CSV::foreach("professors.csv", col_sep: "\t") do |r|
    professors << r
end

CSV::foreach("other.csv", col_sep: "\t") do |r|
    other << r
end

CSV::foreach("places.csv", col_sep: "\t") do |r|
    places << r
end

CSV::foreach("series.csv", col_sep: "\t") do |r|
    series << r
end

CSV::foreach("titles.csv", col_sep: "\t") do |r|
    titles << r
end

def process_name(doc, path, data)
    XPath.each(doc, path) do |name|
        data.each do |old, n|
            if name.text && name.text.strip == old.strip
                if n == "DELETE"
                    name.remove
                    puts "delete #{old}".red
                else
                    name.text = n.strip
                    name.attributes['key'] = n.strip
                    #puts "#{old} => #{n}".yellow
                end
            end
        end
    end
end

def process_key(doc, path, data)
    XPath.each(doc, path) do |place|
        data.each do |old, n|
            if place.attributes['key'] && place.attributes['key'].strip == old.strip
                if n == "DELETE"
                    place.remove
                    #puts "delete #{old}".red
                else
                    place.attributes['key'] = n.strip
                    #puts place.attributes['key']
                end
            end
        end
    end
end

def process_title(doc, path, data)
    XPath.each(doc, path) do |name|
        data.each do |old, n|
            if name.text && name.text.strip == old.strip
                if n == "DELETE"
                    name.text = "[sans titre]"
                    puts "rename #{old}".red
                end
            end
            name.text = "[sans titre]" if !name.text || name.text.empty?
        end
    end
end

files.each do |file|

    doc = REXML::Document.new(File.open(file))

    process_name(doc, "/TEI/text/body/p/name[@role='cmp']", composers)
    process_name(doc, "/TEI/text/body/p/name[@role='int']", interpreters)
    process_name(doc, "/TEI/text/body/p/name[@role='prof']", professors)
    process_name(doc, "/TEI/text/body/p/name[@role='var']", other)

    process_key(doc, "/TEI/text/body/p/placeName", places)
    process_key(doc, "/TEI/text/body/p/name[@type='series']", series)

    process_title(doc, "/TEI/teiHeader/fileDesc/sourceDesc/bibl/title", titles)

    formatted_xml = ""
    formatter = REXML::Formatters::Pretty.new
        
    # Compact uses as little whitespace as possible
    formatter.compact = true
    formatter.width = 20000
    formatter.write(doc, formatted_xml)

    File.open(file, 'w') do |outf|
        outf.write(formatted_xml)
    end

    #doc.write(File.open(file, "w"))
end
