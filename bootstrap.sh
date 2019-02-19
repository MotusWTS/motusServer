# Set up machine
echo "sgdata.bsc-eoc.org" >/etc/hostname

# Add user sg
addgroup sg_remote
adduser sg sg-remote

# Add required packages
apt-get update
apt-get upgrade

apt-get install r-base
apt-get install r-base-dev
apt-get install libgit2-dev
apt-get install libcurl4-openssl-dev
apt-get install libssl-dev
apt-get install mariadb-server
apt-get install libmariadbclient-dev
apt-get install libxml2-dev
apt-get install sqlite3
apt-get install libsqlite3-dev
apt-get install graphviz
apt-get install apache2
apt-get install gdebi
apt-get install libcanberra-gtk-module

# Add R packages
R <<EOF
install.packages('dbplyr')
install.packages('httr')
install.packages('hwriter')
install.packages('lubridate')
install.packages('proto')
install.packages('RCurl')
install.packages('RMySQL')
install.packages('Rook')
install.packages('RSQLite')
install.packages('sendmailR')
install.packages('XML')

EOF
