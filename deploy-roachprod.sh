# Create Cockroach, Kafka and Nifi clusters
export CLUSTER="${USER:0:6}-test"
export COCKROACH=${CLUSTER}:1-3
export HAPROXY=${CLUSTER}:4
export NIFI=${CLUSTER}:5-7
export NIFI_NODE=${CLUSTER}:5

roachprod create ${CLUSTER} -n 7 --local-ssd

# Add gcloud SSH key. Optional for most commands, but some require it.
#ssh-add ~/.ssh/google_compute_engine

echo "----------------"
echo "Stage Binaries"
echo "----------------"

roachprod stage ${CLUSTER} workload
roachprod stage ${CLUSTER} release v19.2.2

echo "----------------"
echo "Start Up Services"
echo "----------------"

# Create Cockroach cluster
echo "installing cockroach..."
roachprod start ${CLUSTER}:1-3

echo "installing haproxy..."
roachprod run ${CLUSTER}:4 'sudo apt-get -qq update'
roachprod run ${CLUSTER}:4 'sudo apt-get -qq install -y haproxy'
roachprod run ${CLUSTER}:4 "./cockroach gen haproxy --insecure --host `roachprod ip $CLUSTER:1 --external`"
roachprod run ${CLUSTER}:4 'cat haproxy.cfg'
roachprod run ${CLUSTER}:4 'haproxy -f haproxy.cfg &' &

# Create NiFi cluster
echo "installing nifi..."
roachprod run ${NIFI} 'sudo apt-get -qq update'
roachprod run ${NIFI} 'sudo apt-get -qq install -y openjdk-8-jre-headless'
roachprod run ${NIFI} 'sudo mkdir -p /opt/nifi'
roachprod run ${NIFI} 'curl -s https://archive.apache.org/dist/nifi/1.9.2/nifi-1.9.2-bin.tar.gz | sudo tar -C /opt/nifi -xz'
roachprod run ${NIFI} 'wget -nv https://jdbc.postgresql.org/download/postgresql-42.2.8.jar'
roachprod put ${NIFI} './Cockroach-Ingest.xml'
roachprod run ${NIFI} 'sudo ln -s /opt/nifi/nifi-1.9.2 /opt/nifi/nifi-current'
roachprod run ${NIFI} 'sudo mkdir -p /opt/nifi/nifi-1.9.2/conf/templates'
roachprod run ${NIFI} 'sudo mkdir -p /opt/nifi/nifi-1.9.2/jdbc'
roachprod run ${NIFI} 'sudo mv Cockroach-Ingest.xml /opt/nifi/nifi-1.9.2/conf/templates'
roachprod run ${NIFI} 'sudo mv postgresql-42.2.8.jar /opt/nifi/nifi-1.9.2/jdbc'

#Backup properties files
#roachprod get ${CLUSTER} /opt/nifi/nifi-1.9.2/conf/nifi.properties ./nifi.properties.orig
#roachprod get ${CLUSTER} /opt/nifi/nifi-1.9.2/conf/zookeeper.properties ./zookeeper.properties.orig
#roachprod get ${CLUSTER} /opt/nifi/nifi-1.9.2/conf/state-management.xml ./state-management.xml.orig

#### NiFi Properties
# State
roachprod run ${NIFI} 'replaceString=true && sudo sed -i "s/\(nifi\.state\.management\.embedded\.zookeeper\.start=\).*\$/\1${replaceString}/" /opt/nifi/nifi-1.9.2/conf/nifi.properties'

# Web
roachprod run ${NIFI} 'replaceString=9090 && sudo sed -i "s/\(nifi\.web\.http\.port=\).*\$/\1${replaceString}/" /opt/nifi/nifi-1.9.2/conf/nifi.properties'
roachprod run ${CLUSTER}:5 'replaceString=chrisc-test-0005 && sudo sed -i "s/\(nifi\.web\.http\.host=\).*\$/\1${replaceString}/" /opt/nifi/nifi-1.9.2/conf/nifi.properties'
roachprod run ${CLUSTER}:6 'replaceString=chrisc-test-0006 && sudo sed -i "s/\(nifi\.web\.http\.host=\).*\$/\1${replaceString}/" /opt/nifi/nifi-1.9.2/conf/nifi.properties'
roachprod run ${CLUSTER}:7 'replaceString=chrisc-test-0007 && sudo sed -i "s/\(nifi\.web\.http\.host=\).*\$/\1${replaceString}/" /opt/nifi/nifi-1.9.2/conf/nifi.properties'

## Clustering
roachprod run ${NIFI} 'replaceString=true && sudo sed -i "s/\(nifi\.cluster\.is\.node=\).*\$/\1${replaceString}/" /opt/nifi/nifi-1.9.2/conf/nifi.properties'
roachprod run ${NIFI} 'replaceString=9088 && sudo sed -i "s/\(nifi\.cluster\.node\.protocol\.port=\).*\$/\1${replaceString}/" /opt/nifi/nifi-1.9.2/conf/nifi.properties'
roachprod run ${CLUSTER}:5 'replaceString=chrisc-test-0005 && sudo sed -i "s/\(nifi\.cluster\.node\.address=\).*\$/\1${replaceString}/" /opt/nifi/nifi-1.9.2/conf/nifi.properties'
roachprod run ${CLUSTER}:6 'replaceString=chrisc-test-0006 && sudo sed -i "s/\(nifi\.cluster\.node\.address=\).*\$/\1${replaceString}/" /opt/nifi/nifi-1.9.2/conf/nifi.properties'
roachprod run ${CLUSTER}:7 'replaceString=chrisc-test-0007 && sudo sed -i "s/\(nifi\.cluster\.node\.address=\).*\$/\1${replaceString}/" /opt/nifi/nifi-1.9.2/conf/nifi.properties'
roachprod run ${NIFI} 'sudo sed -i "s/nifi.cluster.flow.election.max.wait.time=5 mins/nifi.cluster.flow.election.max.wait.time=10 secs/" /opt/nifi/nifi-1.9.2/conf/nifi.properties'

#### Zookeeper
# Remove default entry, add servers to properties file
roachprod run ${NIFI} 'replaceString=chrisc-test-0005:2181,chrisc-test-0006:2181,chrisc-test-0007:2181 && sudo sed -i "s/\(nifi\.zookeeper\.connect\.string=\).*\$/\1${replaceString}/" /opt/nifi/nifi-1.9.2/conf/nifi.properties'
roachprod run ${NIFI} 'sudo sed -i "/server\.1=/d" /opt/nifi/nifi-1.9.2/conf/zookeeper.properties'
roachprod run ${NIFI} 'sudo chmod 777 /opt/nifi/nifi-1.9.2/conf/zookeeper.properties'
roachprod run ${NIFI} 'sudo echo -e "server.1=chrisc-test-0005:2888:3888" >> /opt/nifi/nifi-1.9.2/conf/zookeeper.properties'
roachprod run ${NIFI} 'sudo echo -e "server.2=chrisc-test-0006:2888:3888" >> /opt/nifi/nifi-1.9.2/conf/zookeeper.properties'
roachprod run ${NIFI} 'sudo echo -e "server.3=chrisc-test-0007:2888:3888" >> /opt/nifi/nifi-1.9.2/conf/zookeeper.properties'

# Create zookeeper state folder on all hosts
roachprod run ${NIFI} 'sudo mkdir -p /opt/nifi/nifi-1.9.2/state/zookeeper'
roachprod run ${NIFI} 'sudo chmod 777 /opt/nifi/nifi-1.9.2/state/zookeeper'


#### Add Zookeeper ids on all hosts
roachprod run ${CLUSTER}:5 'sudo echo 1 > /opt/nifi/nifi-1.9.2/state/zookeeper/myid'
roachprod run ${CLUSTER}:6 'sudo echo 2 > /opt/nifi/nifi-1.9.2/state/zookeeper/myid'
roachprod run ${CLUSTER}:7 'sudo echo 3 > /opt/nifi/nifi-1.9.2/state/zookeeper/myid'

#### State Management file
# Under cluster-provider -> provider id add the following
# <property name="Connect String"></property>
roachprod run ${NIFI} 'sudo sed -i "s/<property name=\"Connect String\"><\/property>/<property name=\"Connect String\">chrisc-test-0005:2181,chrisc-test-0006.c.cockroach-ephemeral.internal:2181,chrisc-test-0007.c.cockroach-ephemeral.internal:2181<\/property>/" /opt/nifi/nifi-1.9.2/conf/state-management.xml'

roachprod run ${NIFI} 'sudo rm -f /opt/nifi/nifi-1.9.2/conf/flow.xml.gz'

#roachprod get ${CLUSTER} /opt/nifi/nifi-1.9.2/conf/nifi.properties ./nifi.properties
#roachprod get ${CLUSTER} /opt/nifi/nifi-1.9.2/conf/zookeeper.properties ./zookeeper.properties
#roachprod get ${CLUSTER} /opt/nifi/nifi-1.9.2/conf/state-management.xml ./state-management.xml

roachprod run ${NIFI} 'sudo /opt/nifi/nifi-1.9.2/bin/nifi.sh start'

sleep 60

roachprod run ${NIFI} 'sudo /opt/nifi/nifi-1.9.2/bin/nifi.sh restart'

#### Wait for NiFi to Start
nifinode=`roachprod ip ${NIFI_NODE} --external`

echo -e "Waiting for Nifi to Start"
until $(curl --output /dev/null --silent --head --fail http://$nifinode:9090/nifi); do
    printf '.'
    sleep 5
done

sleep 15

# Find Template to deploy
templateId=$(curl http://$nifinode:9090/nifi-api/flow/templates | jq '.templates[] | select( .template.name=="Cockroach-Ingest") | .id' )

#Get root process group
rootpg=$(curl http://$nifinode:9090/nifi-api/flow/process-groups/root | jq '.processGroupFlow.id'  | sed "s/\"//g")

# Apply template
curl -i -X POST -H 'Content-Type:application/json' -d '{"originX": 2.0,"originY": 3.0,"templateId": '$templateId'}' http://$nifinode:9090/nifi-api/process-groups/$rootpg/template-instance

# Get Controller Services
conserv=$(curl http://$nifinode:9090/nifi-api/flow/process-groups/$rootpg/controller-services | jq '.controllerServices[].component.id' | sed "s/\"//g")

# Enable Controller Services
for id in $conserv
do
  echo "Enabling Controller Servics: " $id
  curl -i -X PUT -H 'Content-Type:application/json' -d '{"state": "ENABLED","revision": {"clientId":"value","version":0}}' http://$nifinode:9090/nifi-api/controller-services/$id/run-status
done

# Get Processors
processors=$(curl http://$nifinode:9090/nifi-api/flow/process-groups/root | jq '.processGroupFlow.flow.processors[].id' | sed "s/\"//g")

# Start Processors
#for p in $processors
#do
#  echo "Enabling Processor: " $p
#  curl -i -X PUT -H 'Content-Type:application/json' -d '{"state": "RUNNING","revision": {"clientId":"value","version":0}}' http://$nifinode:9090/nifi-api/processors/$p/run-status
#done


# Open NiFi
open http://$nifinode:9090/nifi

# Open Cockroach Admin UI
roachprod admin --open --ips ${CLUSTER}:1

echo -e ""
echo -e "NiFi Status:"
roachprod run ${NIFI} 'sudo /opt/nifi/nifi-1.9.2/bin/nifi.sh status'
echo -e ""
echo -e "******** Connect **************"
echo -e "NiFi UI:       http://$nifinode:9090/nifi"
echo -e "Cockroach UI : http://`roachprod ip ${CLUSTER}:1 --external`:8080"
echo -e "Cockroach SQL: cockroach sql --insecure --host `roachprod ip ${CLUSTER}:4 --external` --port 26257"
echo -e "*******************************"


# echo "----------------"
# echo "Run Workloads"
# echo "----------------"

# roachprod run ${CLUSTER}:1 -- "./workload init bank"
# cat sql/bank-roachprod.sql > sql/bank-roachprod2.sql
# echo -e "CREATE CHANGEFEED FOR TABLE bank INTO 'kafka://`roachprod ip ${KAFKA} --external`:9092?topic_prefix=bank_json_' WITH updated, key_in_value, format = json, confluent_schema_registry = 'http://`roachprod ip ${KAFKA} --external`:8081';" >> sql/bank-roachprod2.sql
# roachprod put ${CLUSTER} './sql'
# roachprod run $CLUSTER:1 <<EOF
# ./cockroach sql --insecure --host=`roachprod ip $CLUSTER:1` --echo-sql < sql/bank-roachprod2.sql
# EOF
# Run a workload.
# roachprod run ${CLUSTER}:4 -- ./workload run bank --duration=10m

# Open a SQL connection to the first node.
#roachprod sql ${CLUSTER}:1
