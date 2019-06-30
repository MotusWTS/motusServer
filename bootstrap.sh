# Set up machine
echo "sgdata.bsc-eoc.org" >/etc/hostname
echo "127.0.0.1       sgdata.bsc-eoc.org" >>/etc/hosts

# Add user sg
useradd -m sg
addgroup sg_remote
adduser sg sg_remote
adduser sg sudo
mkdir /sgm
mkdir /sgm/logs

# Add required packages
echo 'deb http://cran.utstat.utoronto.ca/bin/linux/debian jessie-cran35/' >>/etc/apt/sources.list
apt-get update
apt-get upgrade -y

apt-get install -y --force-yes r-base
apt-get install -y libgit2-dev
apt-get install -y libcurl4-openssl-dev
apt-get install -y mariadb-server
apt-get install -y libmariadb-client-lgpl-dev
apt-get install -y libxml2-dev
apt-get install -y sqlite3
apt-get install -y libsqlite3-dev
apt-get install -y graphviz
apt-get install -y apache2
apt-get install -y gdebi
apt-get install -y libcanberra-gtk-module
apt-get install -y git

# Add R packages
R --vanilla <<EOF
install.packages('dbplyr', repos='http://cran.utstat.utoronto.ca/')
install.packages('httr', repos='http://cran.utstat.utoronto.ca/')
install.packages('hwriter', repos='http://cran.utstat.utoronto.ca/')
install.packages('lubridate', repos='http://cran.utstat.utoronto.ca/')
install.packages('proto', repos='http://cran.utstat.utoronto.ca/')
install.packages('RCurl', repos='http://cran.utstat.utoronto.ca/')
install.packages('RMySQL', repos='http://cran.utstat.utoronto.ca/')
install.packages('Rook', repos='http://cran.utstat.utoronto.ca/')
install.packages('RSQLite', repos='http://cran.utstat.utoronto.ca/')
install.packages('sendmailR', repos='http://cran.utstat.utoronto.ca/')
install.packages('XML', repos='http://cran.utstat.utoronto.ca/')
install.packages('roxygen2', repos='http://cran.utstat.utoronto.ca/')

EOF
