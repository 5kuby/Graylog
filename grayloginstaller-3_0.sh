#! /bin/bash
### CHANGE THE FOLLOWING IP WITH THE IP OF YOUR SERVER ####
ip_addr="192.168.18.1"
systemctl start firewalld
firewall-cmd --zone=public --add-port=9000/tcp --permanent
firewall-cmd --zone=public --add-port=22/tcp --permanent
systemctl restart firewalld
echo "
#
#
#
installo rpmfusion
#
#
#"
sleep 1
yum localinstall -y --nogpgcheck https://download1.rpmfusion.org/free/el/rpmfusion-free-release-7.noarch.rpm https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-7.noarch.rpm
echo "
#
#
#
installo alcune utility
#
#
#
"
sleep 1
yum install -y perl-Digest-SHA net-tools.x86_64 pwgen.x86_64 java-1.8.0-openjdk java-1.8.0-openjdk-headless.x86_64
echo "
#
#
#
aggiungo il repo per mongodb
#
#
#
"
sleep 1
echo "[mongodb-org-4.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/4.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-4.0.asc" >> /etc/yum.repos.d/mongodb-org.repo
echo "
#
#
#
Installo mongodb e ne abilito il servizio
#
#
#
"
sleep 1
yum -y install mongodb-org && systemctl enable mongod && systemctl start mongod
echo "
#
#
#
Installo il repo elasticsearch
#
#
#
"
sleep 1
rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
echo "[elasticsearch-6.x]
name=Elasticsearch repository for 6.x packages
baseurl=https://artifacts.elastic.co/packages/oss-6.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md" >> /etc/yum.repos.d/elasticsearch.repo
echo "
#
#
#
Installo e configuro elasticsearch
#
#
#
"
sleep 1
yum -y install elasticsearch-oss
# set graylog as name of elastic cluster
sed -i 's/#cluster.name: my-application/cluster.name: graylog/g' /etc/elasticsearch/elasticsearch.yml
echo 'action.auto_create_index: false' >> /etc/elasticsearch/elasticsearch.yml
chkconfig --add elasticsearch
systemctl daemon-reload
systemctl enable elasticsearch.service
systemctl restart elasticsearch.service
echo "
#
#
#
Installo graylog
#
#
#
"
sleep 1
rpm -Uvh https://packages.graylog2.org/repo/packages/graylog-3.0-repository_latest.rpm
yum -y install graylog-server
# encrypt password remove  - at the end of sha256sum output. the has is stored in the $pass var
pass=$( echo -n graylog | sha256sum | sed 's/-//g')
# inserisco la variabile pass e imposto la password di admin con il valore graylog. Le " in sed elaborano le variabili
sed -i "s/root_password_sha2 =/root_password_sha2 = $pass/g" /etc/graylog/server/server.conf
# do some graylog configuration:
# Set timezone, see http://www.joda.org/joda-time/timezones.html for a list of valid time zones.
sed -i 's|#root_timezone = UTC|root_timezone = Europe/\Rome|g' /etc/graylog/server/server.conf
# Enable web interface and set listen ip
sed -i "s|#http_bind_address = 127.0.0.1:9000|http_bind_address = $ip_addr:9000|g" /etc/graylog/server/server.conf
# set password secret
pass_secret=$(pwgen -N 1 -s 96)
sed -i "s/password_secret =/password_secret = $pass_secret/g" /etc/graylog/server/server.conf
# set some Java options (heap size and ipv4 as preferred stack)
sed -i 's|GRAYLOG_SERVER_JAVA_OPTS="-Xms1g -Xmx1g -XX:NewRatio=1 -server -XX:+ResizeTLAB -XX:+UseConcMarkSweepGC -XX:+CMSConcurrentMTEnabled -XX:+CMSClassUnloadingEnabled -XX:+UseParNewGC -XX:-OmitStackTraceInFastThrow"|GRAYLOG_SERVER_JAVA_OPTS="-Djava.net.preferIPv4Stack=true -Xms4g -Xmx4g -XX:NewRatio=1 -server -XX:+ResizeTLAB -XX:+UseConcMarkSweepGC -XX:+CMSConcurrentMTEnabled -XX:+CMSClassUnloadingEnabled -XX:+UseParNewGC -XX:-OmitStackTraceInFastThrow"|g' /etc/sysconfig/graylog-server
systemctl enable graylog-server
systemctl restart graylog-server
