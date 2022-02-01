require 'rsolr'
require 'nokogiri'
require 'awesome_print'
require 'progress_bar'

if ARGV.count != 2
    puts "Usage: reindex.rb DATA_DIR SOLR_HOST"
    exit 1
end

DATA_DIR = ARGV[0]
SOLR_HOST = ARGV[1]

if !DATA_DIR
    puts "Please specify the absolute path of the TEI files"
    exit 1
end

if !SOLR_HOST
    puts "Please specify SOLR url"
    exit 1
end

solr = RSolr.connect :url => 'http://localhost:8983/solr/onstage'

solr.delete_by_query "*:*"
solr.commit

files = Dir.glob(DATA_DIR + "/**/*.xml")
pb = ProgressBar.new(files.count)

files.each do |file|
    pb.increment!
    next if File.directory?(file)

    solr_fields = {}

    solr_fields[:id] = File.basename(file)
    solr_fields[:manifest_ss] = file.gsub(DATA_DIR + "/", "")

    doc = Nokogiri::XML(File.open(file))
    doc.remove_namespaces!

    solr_fields[:composer_ss] = doc.xpath("//TEI/text/body/p/name[@role='cmp']").collect(&:text)

    solr_fields[:interpreter_ss] = doc.xpath("/TEI/text/body/p/name[@role='int']").collect(&:text)
    solr_fields[:professor_ss] = doc.xpath("/TEI/text/body/p/name[@role='prof']").collect(&:text)
    solr_fields[:other_ss] = doc.xpath("/TEI/text/body/p/name[@role='var']").collect(&:text)
    
    solr_fields[:images_ss] = doc.xpath("/TEI/text/body/p/pb/@facs").collect(&:text)
  
    solr_fields[:place_ss] = doc.xpath("/TEI/text/body/p/placeName/@key").collect(&:text)

    series = doc.xpath("/TEI/text/body/p/name[@type='series']/@key")
    solr_fields[:series_s] = series.first.text if !series.empty?
    
    solr_fields[:collection_s] = doc.xpath("/TEI/teiHeader/fileDesc/seriesStmt/idno").collect(&:text)
  
    solr_fields[:title_s] = doc.xpath("/TEI/teiHeader/fileDesc/sourceDesc/bibl/title").collect(&:text)

    #regex="(^[0-9]{4})"
    solr_fields[:year_is] = doc.xpath("/TEI/text/body/p/date/@when").collect do |item|
        next if !item.text.match("(^[0-9]{4})")
        item.text.to_i.to_s
    end

    solr_fields[:fulldate_ss] = doc.xpath("/TEI/text/body/p/date/@when").collect(&:text)
    
    solr_fields[:note_ss] = doc.xpath("/TEI/teiHeader/fileDesc/notesStmt/note").collect(&:text)
    solr_fields[:idno_ss] = doc.xpath("/TEI/teiHeader/fileDesc/sourceDesc/bibl/idno").collect(&:text)

    solr_fields[:pages_txt] = doc.xpath("/TEI/text/body/p/page").collect(&:text)

    solr.add(solr_fields)

end

solr.commit