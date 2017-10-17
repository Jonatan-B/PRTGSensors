<#
.SYNOPSIS
    This script will grab statistics from the IIS ARR Load Balancer for a particular server and return them to PRTG to serve as a custom sensor. 

.PARAMETER ComputerName
    The Load balancing server.
.PARAMETER ApiNode
    The node where we will be gathering the statistics from. 
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory,Position=0)]
    [string] $ComputerName,
    [Parameter(Mandatory, Position=1)]
    [string] $ApiNode
)

[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.Web.Administration") | Out-Null

try {
    $webServerManager = [Microsoft.Web.Administration.ServerManager]::OpenRemote($ComputerName)
    #$webServerManager = New-object Microsoft.Web.Administration.ServerManager
}
catch {
    '<?xml version="1.0" encoding="Windows-1252" ?>'
    "<prtg>"
    "<Text>Unable to connect to $ComputerName</Text>"
    "<Error>1</Error>"
    "</prtg>"
    exit 2
}


$configuration = $webServerManager.GetApplicationHostConfiguration()
$section = $configuration.GetSection("webFarms") # This is case sensitive
$webFarms = $section.GetCollection()

# Select the first the farm, this is assuming only one farm is in the load balancer. This might change in the future.
$farm = $webFarms[0] 
$servers = $farm.GetCollection()
$server = $servers | Where-Object { $_.GetAttributeValue("address") -eq $ApiNode }

if($server){ # Make sure we were able to find the server. 

    $arr = $server.GetChildElement("applicationRequestRouting")
    $counters = $arr.GetChildElement("counters")
    '<?xml version="1.0" encoding="Windows-1252" ?>'
    "<prtg>"
    ("<result><channel>{0}</channel><value>{1}</value><ValueLookUp>{2}</ValueLookUp></result>" -f "Status", [int]$counters.GetAttributeValue("isHealthy"), "prtg.standardlookups.loadbalancenode.status" )
    ("<result><channel>{0}</channel><value>{1}</value><ValueLookUp>{2}</ValueLookUp></result>" -f "State", $counters.GetAttributeValue("state"), "prtg.standardlookups.loadbalancenode.state" )
    ("<result><channel>{0}</channel><value>{1}</value><Unit>Custom</Unit><CustomUnit>ms</CustomUnit></result>" -f "Response Time (ms)", ([int]$counters.GetAttributeValue("responseTime")) )
    ("<result><channel>{0}</channel><value>{1}</value></result>" -f "Requests per second", $counters.GetAttributeValue("requestPerSecond") )
    ("<result><channel>{0}</channel><value>{1}</value></result>" -f "Current Requests", $counters.GetAttributeValue("currentRequests") )
    ("<result><channel>{0}</channel><value>{1}</value></result>" -f "Failed Requests", $counters.GetAttributeValue("failedRequests") )
    ("<result><channel>{0}</channel><value>{1}</value></result>" -f "Total Requests", $counters.GetAttributeValue("totalRequests") )
    ("<result><channel>{0}</channel><value>{1}</value></result>" -f "Current WebSocket Requests", $counters.GetAttributeValue("currentWebSocketRequests") )
    ("<result><channel>{0}</channel><value>{1}</value></result>" -f "Failed WebSocket Requests", $counters.GetAttributeValue("failedWebSocketRequests") )
    ("<result><channel>{0}</channel><value>{1}</value></result>" -f "Total WebSocket Requests", $counters.GetAttributeValue("totalWebSocketRequests") )
    "</prtg>"

    exit 0
}
else {
    # API node not found.
    '<?xml version="1.0" encoding="Windows-1252" ?>'
    "<prtg>"
    "<Text>Unable to find the api node $ApiNode</Text>"
    "<Error>1</Error>"
    "</prtg>"
    exit 4
}
