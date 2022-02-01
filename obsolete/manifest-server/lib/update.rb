require 'git'
require 'rsolr'

module Update

GIT_DIR = '/Users/xhero/onstage-tei'

    def update_index
        puts "Running index update..."
        Thread.new do
            update_git
            update_solr
        end

    end

    def update_git
        puts "Updating git"
        g = Git.open(GIT_DIR, :log => Logger.new(STDOUT))
        res = g.pull
        ap "Git updated"
    end

    def update_solr
        solr = RSolr.connect :url => 'http://localhost:8983'
        response = solr.get '/solr/onstage/dataimport/', :params => {:command => 'full-import'}
    end

    def get_solr_status
        solr = RSolr.connect :url => 'http://localhost:8983'
        response = solr.get '/solr/onstage/dataimport/', :params => {:command => 'status'}
        return response
    end

end