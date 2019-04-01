# SOLR Installation

1) Get solr, the configuration is made for 8.0.0 [http://lucene.apache.org/solr/downloads.html](http://lucene.apache.org/solr/downloads.html)

2) Unpack it in a suitable location
```
cp solr-8.0.0.tgz $DEST
tar -xvzf solr-8.0.0.tgz
```

3) Clone this git repo in a suitable place too, then link it to solr
```
# go to a suitable directory for the whole backend
git clone https://github.com/rism-ch/onstage-backend onstage
# go back to your solr installation dir
cd solr-8.0.0/server/solr
ln -s $REPOSITORY_DIRECTORY/onstage .
```

4) start solr
```
cd solr-8.0.0
./bin/solr start
```

If everything is ok, solr should be running on ```http://localhost:8983```
