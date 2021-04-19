require "csv"
require "awesome_print"
require "rexml/document" 
require 'progress_bar'
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

CSV::foreach("00_names2.csv", col_sep: "\t") do |r|
    composers << r
end

CSV::foreach("00_interpreters2.csv", col_sep: "\t") do |r|
    interpreters << r
end

CSV::foreach("00_professors2.csv", col_sep: "\t") do |r|
    professors << r
end

CSV::foreach("00_other2.csv", col_sep: "\t") do |r|
    other << r
end

CSV::foreach("00_places2.csv", col_sep: "\t") do |r|
    places << r
end

CSV::foreach("00_series2.csv", col_sep: "\t") do |r|
    series << r
end

CSV::foreach("00_titles2.csv", col_sep: "\t") do |r|
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
                    puts "#{old} => #{n}".yellow
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

def process_date(doc, path)
    XPath.each(doc, path) do |name|
        if name.attributes['when'].include?('--')
            name.attributes['when'] = name.attributes['when'].gsub('-', '0')
        end
    end
end

pb = ProgressBar.new(files.count) 
files.each do |file|

    doc = REXML::Document.new(File.open(file))

    # For just one
    interpreters = [["Harmonie Nautique ", "Harmonie Nautique"], ["Corps de musique d'Elite ", "Corps de musique d'Elite"]]

    #process_name(doc, "/TEI/text/body/p/name[@role='cmp']", composers)
    process_name(doc, "/TEI/text/body/p/name[@role='int']", interpreters)
    #process_name(doc, "/TEI/text/body/p/name[@role='prof']", professors)
    #process_name(doc, "/TEI/text/body/p/name[@role='var']", other)

    # For manually entered places
    #places = [["Genève, Kiosque des Bastions ", "Genève, Kiosque des Bastions"]]
    #process_key(doc, "/TEI/text/body/p/placeName", places)

    #process_key(doc, "/TEI/text/body/p/name[@type='series']", series)

    #process_title(doc, "/TEI/teiHeader/fileDesc/sourceDesc/bibl/title", titles)

    #process_date(doc, "/TEI/text/body/p/date")

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
    pb.increment!

end
