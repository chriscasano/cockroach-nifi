export nifinode=localhost
export nifiport=9095
export nifiurl=$nifinode:$nifiport

echo -e "Waiting for Nifi to Start"
until $(curl --output /dev/null --silent --head --fail http://$nifiurl/nifi); do
    printf '.'
    sleep 5
done

sleep 15

# Find Template to deploy
echo "Find template"
templateId=$(curl http://$nifiurl/nifi-api/flow/templates | jq '.templates[] | select( .template.name=="Cockroach-Ingest-Docker") | .id' )

#Get root process group
echo "Get root process group"
rootpg=$(curl http://$nifiurl/nifi-api/flow/process-groups/root | jq '.processGroupFlow.id'  | sed "s/\"//g")

# Apply template
echo "Apply template"
curl -i -X POST -H 'Content-Type:application/json' -d '{"originX": 2.0,"originY": 3.0,"templateId": '$templateId'}' http://$nifiurl/nifi-api/process-groups/$rootpg/template-instance

# Get Controller Services
echo "Get Controller Services"
conserv=$(curl http://$nifiurl/nifi-api/flow/process-groups/$rootpg/controller-services | jq '.controllerServices[].component.id' | sed "s/\"//g")

# Enable Controller Services
echo "Start services"
for id in $conserv
do
  echo "Enabling Controller Servics: " $id
  curl -i -X PUT -H 'Content-Type:application/json' -d '{"state": "ENABLED","revision": {"clientId":"value","version":0}}' http://$nifiurl/nifi-api/controller-services/$id/run-status
done

# Get Processors
echo "Get processors"
processors=$(curl http://$nifiurl/nifi-api/flow/process-groups/root | jq '.processGroupFlow.flow.processors[].id' | sed "s/\"//g")

# Start Processors
#for p in $processors
#do
#  echo "Enabling Processor: " $p
#  curl -i -X PUT -H 'Content-Type:application/json' -d '{"state": "RUNNING","revision": {"clientId":"value","version":0}}' http://$nifinode:9090/nifi-api/processors/$p/run-status
#done


# Open NiFi
open http://$nifiurl/nifi
# Open Cockroach UI
open http://localhost:8090

# Open Cockroach Admin UI
echo -e "******** Connect **************"
echo -e "NiFi UI: http://localhost:9095/nifi"
echo -e "Cockroach Admin UI: http://localhost:8090"
echo -e "SQL (local crdb): cockroach sql --insecure --host localhost --port 5432 --database defaultdb"
echo -e "SQL (no local crdb): docker exec -it roach-0 /cockroach/cockroach.sh sql --insecure --host haproxy --port 5432 --database defaultdb"
echo -e "*******************************"
