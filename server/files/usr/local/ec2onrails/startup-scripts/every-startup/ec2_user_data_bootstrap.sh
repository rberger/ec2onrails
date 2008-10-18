# From http://developer.amazonwebservices.com/connect/entry.jspa?externalID=1085&categoryID=100
# retrieves the user data and acts on the configuration parameters sent at launch time

wget http://169.254.169.254/1.0/user-data \ 
  -O /tmp/payload.zip

# if wget error code is 0, there was no error
if [ "$?" -e "0" ]; then

  mkdir /tmp/payload
  unzip /tmp/payload.zip -d /tmp/payload/ -o

  # if unzip error code is 0, there was no error
  if [ "$?" -e "0" ]; then
	
    # if the autorun.sh script exists, run it
    if [ -x /tmp/payload/autorun.sh ]; then

      sh /tmp/payload/autorun.sh

    else
      echo rc.local : No autorun script to run
    fi

  else
    echo rc.local : payload.zip is corrupted
  fi
	
else
  echo rc.local : error retrieving user data
fi