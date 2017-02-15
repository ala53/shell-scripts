#If you're running a basic cluster using Apache cassandra,
#this script, when executed from a server in the cluster
#will install cassandra, clone the cluster configuration to another SSH enabled server,
#repair the cluster, and add that node to the cluster (updating the cassandra.yaml listen_address as well)
#just run ./clone_cassandra.sh and enter remote username, remote password, and remote IP to connect to

#set -x
LOCAL_IP=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')
read -p "Enter remote username: " SERVER_USERNAME
read -p "Enter remote password: " SERVER_PASS
read -p "Enter remote ip: " SERVER_IP


#install sshpass
apt-get install sshpass

sshpass -p$SERVER_PASS ssh -o StrictHostKeyChecking=no $SERVER_USERNAME@$SERVER_IP 'bash -s' << ENDSSH
sudo apt-get install curl -y
echo "deb http://www.apache.org/dist/cassandra/debian 310x main" | sudo tee -a /etc/apt/sources.list.d/cassandra.sources.list
curl https://www.apache.org/dist/cassandra/KEYS | sudo apt-key add - 

sudo apt-get update -y
sudo apt-get install openjdk-8-jre openjdk-8-jdk cassandra -y --allow-unauthenticated

sudo service cassandra stop
rm -rf /var/lib/cassandra/commitlog/ /var/lib/cassandra/data/

ENDSSH

#Push local config
sshpass -p$SERVER_PASS scp /etc/cassandra/cassandra.yaml $SERVER_USERNAME@$SERVER_IP:/etc/cassandra/cassandra.yaml.tmp
#remotely edit the cassandra.yaml
sshpass -p$SERVER_PASS ssh -o StrictHostKeyChecking=no $SERVER_USERNAME@$SERVER_IP 'bash -s' << ENDSSH

cat /etc/cassandra/cassandra.yaml.tmp | sed 's/listen_address: $LOCAL_IP/listen_address: $SERVER_IP/g' | sed 's/rpc_address: $LOCAL_IP/rpc_address: $SERVER_IP/g' > /etc/cassandra/cassandra.yaml; echo updated; exit; 

ENDSSH

echo Restarting cassandra
sshpass -p$SERVER_PASS ssh -o StrictHostKeyChecking=no $SERVER_USERNAME@$SERVER_IP 'bash -s' << ENDSSH
service cassandra restart
ENDSSH

sleep 30s

echo Rebuilding nodes
nodetool repair

echo Complete
nodetool status
