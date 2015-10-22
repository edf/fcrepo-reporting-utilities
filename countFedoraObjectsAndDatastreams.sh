#/bin/bash
# -edf 2014-0908

FedoraUser=fedoraAdminUser
FedoraUserPassword=fedoraAdminPassword
FedoraHostname="http://yourserver.domain.net"   # example http://fedora.coalliance.org
FedoraPort=":8080"
FedoraContext="/fedora"
FedoraServer="$FedoraHostname$FedoraPort$FedoraContext"

resultObject=$(curl -s -u $FedoraUser:$FedoraUserPassword -X POST "$FedoraServer/risearch?type=tuples&lang=sparql&format=count&dt=on&query=SELECT%20%3Fobj%20FROM%20%3C%23ri%3E%20WHERE%20%7B%20%3Fobj%20%3Cinfo%3Afedora%2Ffedora-system%3Adef%2Fmodel%23hasModel%3E%20%3Cinfo%3Afedora%2Ffedora-system%3AFedoraObject-3.0%3E%20.%20%20%7D")
echo "$FedoraHostname - $resultObject objects"

resultDatastream=$(curl -s -u $FedoraUser:$FedoraUserPassword -X POST "$FedoraServer/risearch?type=tuples&lang=sparql&format=count&dt=on&query=SELECT%20%3Fobj%20%3Fds%20FROM%20%3C%23ri%3E%20WHERE%20%7B%3Fobj%20%3Cinfo%3Afedora%2Ffedora-system%3Adef%2Fview%23disseminates%3E%20%3Fds%20.%20%7D")
echo "$FedoraHostname - $resultDatastream datastreams"
