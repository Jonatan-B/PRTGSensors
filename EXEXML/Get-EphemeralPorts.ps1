param(
    [Parameter(Mandatory)]
    $ComputerName
)

$myScriptBlock = [scriptblock]{
    $connections = Get-NetTCPConnection
	if($connections){    
		$maxNumberOfPorts = (( Get-NetTCPSetting ).DynamicPortRangeNumberOfPorts | Sort-Object -Descending)[0]
		$startPortRange = (( Get-NetTCPSetting ).DynamicPortRangeStartPort | Sort-Object -Descending)[0]
	
		$OutboundConnections = $connections | Where-Object { $_.LocalPort -in $startPortRange..($startPortRange+$maxNumberOfPorts)}
		$totalConnections = $OutboundConnections.length
		$listenConnections = ($OutboundConnections | Where-Object { $_.State -eq "Listen"}).length
		$boundConnections = ($OutboundConnections | Where-Object { $_.State -eq "Bound"}).length
		$EstablishedConnections = ($OutboundConnections | Where-Object { $_.State -eq "Established"}).length
		$TimeWaitConnections = ($OutboundConnections | Where-Object { $_.State -eq "TimeWait"}).length
	
		
		$object = New-Object psobject
		$object | Add-Member -MemberType NoteProperty -Name "TotalConnections" -Value $totalConnections
		$object | Add-Member -MemberType NoteProperty -Name "BoundConnections" -Value $boundConnections
		$object | Add-Member -MemberType NoteProperty -Name "ListenConnections" -Value $listenConnections
		$object | Add-Member -MemberType NoteProperty -Name "EstablishedConnections" -Value $EstablishedConnections
		$object | Add-Member -MemberType NoteProperty -Name "TimeWaitConnections" -Value $TimeWaitConnections
		$object | Add-Member -MemberType NoteProperty -Name "MaximumConnections" -Value $maxNumberOfPorts
	
		$object
	}
}

'<?xml version="1.0" encoding="Windows-1252" ?>'
"<prtg>"

try {
    $status = Invoke-Command -ComputerName $ComputerName -ScriptBlock $myScriptBlock -ErrorAction Stop
}
catch { 
    "<Text>Unable to establish a connection to $ComputerName.</Text>"
    "<Error>1</Error>"
    "</prtg>"
    exit 2
}

if($status)
{

	$ePortsNumber = $status.TotalConnections
    $ePortUsagePercentage = [Math]::Round( ( ($status.TotalConnections / $status.MaximumConnections) * 100),2 )

    ("<result>
    <channel>{0}</channel>
    <value>{1}</value>
    <Unit>{2}</Unit>
    <CustomUnit>{3}</CustomUnit>
    <float>1</float>
    <LimitMaxWarning>90</LimitMaxWarning>
    <LimitMaxError>95</LimitMaxError>
    <LimitMode>1</LimitMode>
    </result>"                          -f 'Percentage used', $ePortUsagePercentage, "Custom", "%" ) 

    ("<result>
    <channel>{0}</channel>
    <value>{1}</value>
    <Unit>{2}</Unit>
    <CustomUnit>{3}</CustomUnit>
    </result>"                          -f 'Number of Epheral Ports', $ePortsNumber, "Custom", "#" ) 

	("<result>
    <channel>{0}</channel>
    <value>{1}</value>
    <Unit>{2}</Unit>
    <CustomUnit>{3}</CustomUnit>
    </result>"                          -f 'Bound Connections', $status.boundConnections, "Custom", "#" ) 

	("<result>
    <channel>{0}</channel>
    <value>{1}</value>
    <Unit>{2}</Unit>
    <CustomUnit>{3}</CustomUnit>
    </result>"                          -f 'Listen Connections', $status.ListenConnections, "Custom", "#" ) 

	("<result>
    <channel>{0}</channel>
    <value>{1}</value>
    <Unit>{2}</Unit>
    <CustomUnit>{3}</CustomUnit>
    </result>"                          -f 'Established Connections', $status.EstablishedConnections, "Custom", "#" ) 

	("<result>
    <channel>{0}</channel>
    <value>{1}</value>
    <Unit>{2}</Unit>
    <CustomUnit>{3}</CustomUnit>
    </result>"                          -f 'TimeWait Connections', $status.TimeWaitConnections, "Custom", "#" ) 

	("<result>
    <channel>{0}</channel>
    <value>{1}</value>
    <Unit>{2}</Unit>
    <CustomUnit>{3}</CustomUnit>
    </result>"                          -f 'Maximum number of Epheral Ports', $status.MaximumConnections, "Custom", "#" ) 
    "</prtg>"
    exit 0
}
else
{
    "<Text>No data was returned by $ComputerName</Text>"
    "<Error>1</Error>"
    "</prtg>"
    exit 2
}