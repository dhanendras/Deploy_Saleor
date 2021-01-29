#########################################################################################
# Saleor_Production_Deployment.sh
# Author:       Aaron K. Nall   http://github.com/thewhiterabbit
#########################################################################################
#!/bin/sh
set -e

#########################################################################################
# Get the actual user that logged in
#########################################################################################
UN="$(who am i | awk '{print $1}')"
if [[ "$UN" != "root" ]]; then
        HD="/home/$UN"
else
        HD="/root"
fi
#########################################################################################



#########################################################################################
# Get the operating system
#########################################################################################
IN=$(uname -a)
arrIN=(${IN// / })
IN2=${arrIN[3]}
arrIN2=(${IN2//-/ })
OS=${arrIN2[1]}
#########################################################################################



#########################################################################################
# Parse options
#########################################################################################
while [ -n "$1" ]; do # while loop starts
	case "$1" in
                -name)
                        DEPLOYED_NAME="$2"
                        shift
                        ;;

                -host)
                        API_HOST="$2"
                        shift
                        ;;

                -uri)
                        APP_MOUNT_URI="$2"
                        shift
                        ;;

                -url)
                        STATIC_URL="$2"
                        shift
                        ;;

                -dbhost)
                        PGDBHOST="$2"
                        shift
                        ;;

                -dbport)
                        DBPORT="$2"
                        shift
                        ;;

                -repo)
                        REPO="$2"
                        shift
                        ;;

                -v)
                        vOPT="true"
                        VERSION="$2"
                        shift
                        ;;

                *)
                        echo "Option $1 is invalid."
                        echo "Exiting"
                        exit 1
                        ;;
	esac
	shift
done
#########################################################################################



#########################################################################################
# Echo the detected operating system
#########################################################################################
echo ""
echo "$OS detected"
echo ""
sleep 3
#########################################################################################



#########################################################################################
# Select/run Operating System specific commands
#########################################################################################
# Tested working on Ubuntu Server 20.04
# Needs testing on the distributions listed below:
#       Debian
#       Fedora CoreOS
#       Kubernetes
#       SUSE CaaS
echo "Installing core dependencies..."
case "$OS" in
        Debian)
                sudo apt-get update
                sudo apt-get install -y build-essential python3-dev python3-pip python3-cffi python3-venv gcc
                sudo apt-get install -y libcairo2 libpango-1.0-0 libpangocairo-1.0-0 libgdk-pixbuf2.0-0 libffi-dev shared-mime-info
                sudo apt-get install -y nodejs npm postgresql postgresql-contrib
                ;;

        Fedora)
                ;;

        Kubernetes)
                ;;

        SUSE)
                ;;

        Ubuntu)
                sudo apt-get update
                sudo apt-get install -y build-essential python3-dev python3-pip python3-cffi python3-venv gcc
                sudo apt-get install -y libcairo2 libpango-1.0-0 libpangocairo-1.0-0 libgdk-pixbuf2.0-0 libffi-dev shared-mime-info
                sudo apt-get install -y nodejs npm postgresql postgresql-contrib
                ;;

        *)
                # Unsupported distribution detected, exit
                echo "Unsupported Linix distribution detected."
                echo "Exiting"
                exit 1
                ;;
esac
#########################################################################################



#########################################################################################
# Tell the user what's happening
#########################################################################################
echo ""
echo "Finished installing core dependencies"
echo ""
sleep 3
echo "Setting up security feature details..."
echo ""
#########################################################################################



#########################################################################################
# Generate a secret key file
#########################################################################################
# Does the key file directory exiet?
if [ ! -d "/etc/saleor" ]; then
        sudo mkdir /etc/saleor
else
        # Does the key file exist?
        if [ -f "/etc/saleor/api_sk" ]; then
                # Yes, remove it.
                sudo rm /etc/saleor/api_sk
        fi
fi
# Create randomized 2049 byte key file
sudo echo $(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 2048| head -n 1) > /etc/saleor/api_sk
#########################################################################################



#########################################################################################
# Set variables for the password, obfuscation string, and user/database names
#########################################################################################
# Generate an 8 byte obfuscation string for the database name & username 
OBFSTR=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8| head -n 1)
# Append the database name for Saleor with the obfuscation string
PGSQLDBNAME="saleor_db_$OBFSTR"
# Append the database username for Saleor with the obfuscation string
PGSQLUSER="saleor_dbu_$OBFSTR"
# Generate a 128 byte password for the Saleor database user
# TODO: Add special characters once we know which ones won't crash the python script
PGSQLUSERPASS=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | fold -w 128 | head -n 1)
#########################################################################################



#########################################################################################
# Tell the user what's happening
#########################################################################################
echo "Finished setting up security feature details"
echo ""
sleep 1
echo "Creating database..."
echo ""
#########################################################################################



#########################################################################################
# Create a superuser for Saleor
#########################################################################################
# Create the role in the database and assign the generated password
sudo -i -u postgres psql -c "CREATE ROLE $PGSQLUSER PASSWORD '$PGSQLUSERPASS' SUPERUSER CREATEDB CREATEROLE INHERIT LOGIN;"
# Create the database for Saleor
sudo -i -u postgres psql -c "CREATE DATABASE $PGSQLDBNAME;"
# TODO - Secure the postgers user account
#########################################################################################



#########################################################################################
# Tell the user what's happening
#########################################################################################
echo "Finished creating database" 
echo ""
sleep 3
#########################################################################################



#########################################################################################
# Collect input from the user to assign required installation parameters
#########################################################################################
echo "Please provide details for your Saleor API instillation..."
echo ""
# Get the Dashboard & GraphQL host domain
while [ "$HOST" = "" ]
do
        echo -n "Enter the Dashboard & GraphQL host domain:"
        read HOST
done
# Get the API host IP or domain
while [ "$API_HOST" = "" ]
do
        echo ""
        echo -n "Enter the API host IP or domain:"
        read API_HOST
done
# Get an optional custom API port
echo -n "Enter the API port (optional):"
read API_PORT
# Get the APP Mount (Dashboard) URI
while [ "$APP_MOUNT_URI" = "" ]
do
        echo ""
        echo -n "Enter the Dashboard URI:"
        read APP_MOUNT_URI
done
# Get an optional custom Static URL
echo -n "Enter a custom Static Files URI (optional):"
read STATIC_URL
# Get the Admin's email address
while [ "$EMAIL" = "" ]
do
        echo ""
        echo -n "Enter the Dashboard admin's email:"
        read EMAIL
done
# Get the Admin's desired password
while [ "$PASSW" = "" ]
do
        echo ""
        echo -n "Enter the Dashboard admin's desired password:"
        read -s PASSW
done
#########################################################################################



#########################################################################################
# Set default and optional parameters
#########################################################################################
if [ "$PGDBHOST" = "" ]; then
        PGDBHOST="localhost"
fi
#
if [ "$DBPORT" = "" ]; then
        DBPORT="5432"
fi
#
if [[ "$GQL_PORT" = "" ]]; then
        GQL_PORT="9000"
fi
#
if [[ "$API_PORT" = "" ]]; then
        API_PORT="8000"
fi
#
if [ "$APIURI" = "" ]; then
        APIURI="graphql" 
fi
#
if [ "$vOPT" = "true" ]; then
        if [ "$VERSION" = "" ]; then
                VERSION="2.11.1"
        fi
fi
#########################################################################################



#########################################################################################
# Open the selected ports for the API and APP
#########################################################################################
# Open GraphQL port
sudo ufw allow $GQL_PORT
# Open API port
sudo ufw allow $API_PORT
#########################################################################################



#########################################################################################
# Clone the Saleor Git repository
#########################################################################################
# Make sure we're in the user's home directory
cd $HD
# Does the Saleor Dashboard already exist?
if [ -d "$HD/saleor" ]; then
        # Remove /saleor directory
        sudo rm -R $HD/saleor
        wait
fi
#
echo "Cloning Saleor from github..."
echo ""
# Check if the -v (version) option was used
if [ "$vOPT" = "true" ]; then
        # Get the Mirumee repo
        git clone https://github.com/mirumee/saleor.git
else
        # Was a repo specified?
        if [ "$REPO" = "mirumee" ]; then
                # Get the Mirumee repo
                git clone https://github.com/mirumee/saleor.git
        else
                # Get the forked repo from thewhiterabbit
                git clone https://github.com/thewhiterabbit/saleor.git
        fi
fi
wait
#########################################################################################



#
echo "Github cloning complete"
echo ""



#########################################################################################
# Replace any parameter slugs in the template files with real paramaters & write them to
# the production files
#########################################################################################
# Does an old saleor.service file exist?
if [ -f "/etc/systemd/system/saleor.service" ]; then
        # Remove the old service file
        sudo rm /etc/systemd/system/saleor.service
fi
# Was the -v (version) option used or Mirumee repo specified?
if [ "vOPT" = "true" ] || [ "$REPO" = "mirumee" ]; then
        # Create the new service file
        sudo sed "s/{un}/$UN/
                  s|{hd}|$HD|" $HD/Deploy_Saleor/resources/saleor/template.service > /etc/systemd/system/saleor.service
        wait
        # Does an old server block exist?
        if [ -f "/etc/nginx/sites-available/saleor" ]; then
                # Remove the old service file
                sudo rm /etc/nginx/sites-available/saleor
        fi
        # Create the new server block
        sudo sed "s|{hd}|$HD|g
                  s/{api_host}/$API_HOST/
                  s/{host}/$HOST/g
                  s/{apiport}/$API_PORT/" $HD/Deploy_Saleor/resources/saleor/server_block > /etc/nginx/sites-available/saleor
        wait
        # Replace demo credentials with production credentials in /saleor/saleor/core/management/commands/populatedb.py
        sudo sed -i "s/{\"email\": \"admin@example.com\", \"password\": \"admin\"}/{\"email\": \"$EMAIL\", \"password\": \"$PASSW\"}/" $HD/saleor/saleor/core/management/commands/populatedb.py
        wait
        # Replace demo credentials with production credentials in /saleor/saleor/core/tests/test_core.py
        sudo sed -i "s/{\"email\": \"admin@example.com\", \"password\": \"admin\"}/{\"email\": \"$EMAIL\", \"password\": \"$PASSW\"}/" $HD/saleor/saleor/core/tests/test_core.py
        wait
        # Replace the insecure demo secret key assignemnt with a more secure file reference in /saleor/saleor/settings.py
        sudo sed -i "s|SECRET_KEY = os.environ.get(\"SECRET_KEY\")|with open('/etc/saleor/api_sk') as f: SECRET_KEY = f.read().strip()|" $HD/saleor/saleor/settings.py
        wait
else
        # Create the new service file
        sudo sed "s/{un}/$UN/
                  s|{hd}|$HD|" $HD/saleor/resources/saleor/template.service > /etc/systemd/system/saleor.service
        wait
        # Does an old server block exist?
        if [ -f "/etc/nginx/sites-available/saleor" ]; then
                # Remove the old service file
                sudo rm /etc/nginx/sites-available/saleor
        fi
        # Create the new server block
        sudo sed "s|{hd}|$HD|
                  s/{api_host}/$API_HOST/
                  s/{host}/$HOST/g
                  s/{apiport}/$API_PORT/" $HD/saleor/resources/saleor/server_block > /etc/nginx/sites-available/saleor
        wait
        # Set the production credentials in /saleor/saleor/core/management/commands/populatedb.py
        sudo sed -i "s/{email}/$EMAIL/
                     s/{passw}/$PASSW/" $HD/saleor/saleor/core/management/commands/populatedb.py
        wait
        # Set the production credentials in /saleor/saleor/core/tests/test_core.py
        sudo sed -i "s/{email}/$EMAIL/
                     s/{passw}/$PASSW/" $HD/saleor/saleor/core/tests/test_core.py
        wait
fi
#########################################################################################



#########################################################################################
# Tell the user what's happening
echo "Creating production deployment packages for Saleor API & GraphQL..."
echo ""
#########################################################################################



#########################################################################################
# Setup the environment variables for Saleor API
#########################################################################################
# Build the database URL
DB_URL="postgres://$PGSQLUSER:$PGSQLUSERPASS@$PGDBHOST:$DBPORT/$PGSQLDBNAME"
EMAIL_URL="smtp://$EMAIL:$EMAIL_PW@$EMAIL_HOST:/?ssl=True"
# Build the chosts and ahosts lists
C_HOSTS="$HOST,$API_HOST,localhost,127.0.0.1"
A_HOSTS="$HOST,$API_HOST,localhost,127.0.0.1"
QL_ORIGINS="$HOST,$API_HOST,localhost,127.0.0.1"
# Write the production .env file from template.env
sudo sed "s|{dburl}|$DB_URL|
          s|{emailurl}|$EMAIL_URL|
          s/{chosts}/$C_HOSTS/
          s/{ahosts}/$A_HOSTS/
          s/{gqlorigins}/$QL_ORIGINS/" $HD/Deploy_Saleor/resources/saleor/template.env > $HD/saleor/.env
wait
#########################################################################################



#########################################################################################
# Copy the uwsgi_params file to /saleor/uwsgi_params
#########################################################################################
sudo cp $HD/Deploy_Saleor/uwsgi_params $HD/saleor/uwsgi_params
#########################################################################################



#########################################################################################
# Install Saleor for production
#########################################################################################
# Make sure we're in the project root directory for Saleor
cd $HD/saleor
# Was the -v (version) option used?
if [ "vOPT" = "true" ]; then
        # Checkout the specified version
        git checkout $VERSION
        wait
fi
# Create vassals directory in virtual environment
if [ ! -d "$HD/env" ]; then
        mkdir $HD/env
        wait
fi
# Does an old virtual environment for Saleor exist?
if [ ! -d "$HD/env/saleor" ]; then
        # Create a new virtual environment for Saleor
        python3 -m venv $HD/env/saleor
        wait
fi
# Create vassals directory in virtual environment
if [ ! -d "$HD/env/saleor/vassals" ]; then
        mkdir $HD/env/saleor/vassals
        wait
        sudo ln -s $HD/saleor/saleor/wsgi/uwsgi.ini $HD/env/saleor/vassals
        wait
fi
wait
# Activate the virtual environment
source $HD/env/saleor/bin/activate
# Make sure pip is upgraded
python3 -m pip install --upgrade pip
wait
# Install Django
pip3 install Django
wait
# Install uwsgi
pip3 install uwsgi
wait
# Install the project requirements
pip3 install -r requirements.txt
wait
# Install the project
npm install
# Run an audit to fix any vulnerabilities
npm audit fix
# Establish the database
python3 manage.py migrate
# Collect the static elemants
python3 manage.py collectstatic
# Build the schema
npm run build-schema
# Build the emails
npm run build-emails
# Exit the virtual environment here? _#_
deactivate
#########################################################################################



#########################################################################################
# Create the Saleor service
#########################################################################################
# Touch
sudo touch /etc/init.d/saleor
# Allow execute
sudo chmod +x /etc/init.d/saleor
# Update with defaults
sudo update-rc.d saleor defaults
#########################################################################################



#########################################################################################
echo "Enabling server block and Restarting nginx..."
sudo ln -s /etc/nginx/sites-available/saleor /etc/nginx/sites-enabled/
sudo systemctl restart nginx
#########################################################################################



#########################################################################################
# Tell the user what's happening
#########################################################################################
echo ""
echo "Finished creating production deployment packages for Saleor API & GraphQL"
echo ""
#########################################################################################