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

# Data installation and index

1) Unzip the sample data (which is the whole onstage dataset at the moment of writing) again in a suitable place
```
unzip sample-data/TEI-transform.zip
```

2) Modify the SOLR index config file so it finds your directory ```onstage/conf/onstage-import.xml```. You need to set ```basePath``` to the directory that contains the ```TEI-transform/``` dir, and baseDir (circa line 12) to the full path of ```TEI-transform/```.

3) In the SOLR console, select the ```onstage``` core and in ```DataImport``` execute the importer.

4) If everything is good, running an empty query (the default in the query window) should return all records.

# Data removal

Sometimes it is useful to wipe the index... On the macchine running it:

```
curl http://localhost:8983/solr/onstage/update?commit=true -H "Content-Type: text/xml" --data-binary '<delete><query>*:*</query></delete>'
```

# Poll the index
A status of the import is availabe at ```/solr_status```.

Configuring the GIT auto-pull backend
--------------------------------------

A local copy of the git repo with the TEI files should be configured to use a user that is read only for the repo. A password can be saved, or if the repo is public no password is needed.
Ensure that the password password prompt is not shown anymore or the webhook will not work

```
git clone <the-repo>
cd the-repo
git config credential.helper store
git pull
```

In a production env things can be more comples, as the server is often run with a low privilege user. This requires some magic more. For example, using the user ```nobody```:

```
git clone <the-repo>
chown -R nobody:nouser the-repo
cd the-repo
sudo -u nobody touch .credential
sudo -u nobody git config credential.helper 'store --file=<the-repo-full-path>/.credential'
sudo -u nobody git pull
```

Run the manifest sever
----------------------

The JSON manifest files for diva can be generated on the fly with the handy server in ```manifest-server```. It is a small http server written with Sinatra. To run it, you need ruby 2 and bundler, then run:

```
bundle install
bundle exec ruby manifest-server.rb
```

This will run the server on localhost. To make it actually work edit ```manifest-server.rb``` and set ```IIF_PATH``` and ```TEI_PATH``` to the URL of the IIIF server and the transformed TEI files used for indexing.

The server can also be deployed with Passenger as a normal ruby app (but using sinatra instead of rails):

```
<VirtualHost *:80>
        # ServerName www..org
        DocumentRoot /var/www/onstage-backend/manifest-server/public
        <Directory "/var/www/onstage-backend/manifest-serverpublic">
                Options All -Indexes +ExecCGI -Includes +MultiViews
                AllowOverride All
                Order allow,deny
                Allow from all
        </Directory>
        RackEnv production
	Header set Access-Control-Allow-Origin "*"
</VirtualHost>
```

Note the ```Access-Control-Allow-Origin```, this is necessary so Diva.js can access the generated json files.

You can interrogate the server by passing the xml file name of one of the items in the OnStage database:

```
curl http://<server>/manifest/CH_Gc_prg_12-1140.xml
```

Run locally
-----------

```exec rackup config.ru```