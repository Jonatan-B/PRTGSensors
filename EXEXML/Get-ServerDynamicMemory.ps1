param(
    [Parameter(Mandatory)]
    $ComputerName
)

Get-Module -Name Microsoft.Powershell.* -ListAvailable | Import-Module

'<?xml version="1.0" encoding="Windows-1252" ?>'
"<prtg>"

try { 
    $MaxAvailableMemory = Get-Counter -ComputerName $ComputerName -Counter '\Hyper-V Dynamic Memory Integration Service\Maximum Memory, Mbytes' -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty CounterSamples |
    Select-Object -ExpandProperty CookedValue
}
catch {
    "<Text>Error: Get Hyper-V Counter - $($_.Exception)</Text>"
    "<Error>1</Error>"
    "</prtg>"
    exit 2
}

if(!($MaxAvailableMemory)){ # Check if the counter returned nothing. If it did it means this is not a VM or it is not using Dynamic Memory.
    try {
        $MaxAvailableMemory = (Get-WmiObject -ComputerName $ComputerName -Class Win32_ComputerSystem).totalPhysicalMemory/1MB
    }
    catch {
        "<Text>Error: Get Total Physical Memory - $($_.Exception)</Text>"
        "<Error>1</Error>"
        "</prtg>"
        exit 2
    }
}

if($MaxAvailableMemory){
    $MaxAvailableMemoryInGB = [Math]::Round("$( $MaxAvailableMemory )MB"/1GB, 2)
}
else {
    "<Text>Error: No data returned when querying for the max available memory.</Text>"
    "<Error>1</Error>"
    "</prtg>"
    exit 2
}

try { 
    $CurrentUsedMemoryInGB = [Math]::Round((Get-Counter -ComputerName $ComputerName -Counter '\Process(_total)\Working Set' | 
    Select-Object -ExpandProperty CounterSamples | 
    Select-Object -ExpandProperty CookedValue)/1GB, 2)
}
catch {
    "<Text>Error: Current Memory on Total_ - $($_.Exception)</Text>"
    "<Error>1</Error>"
    "</prtg>"
    exit 2
}   

if(!($CurrentUsedMemoryInGB)){
    "<Text>Error: No data returned when querying for currently used memory.</Text>"
    "<Error>1</Error>"
    "</prtg>"
    exit 2
}

$AvailableMemory = $MaxAvailableMemoryInGB - $CurrentUsedMemoryInGB
$PercentAvailable = 100 - [Math]::Round( ($CurrentUsedMemoryInGB / $MaxAvailableMemoryInGB) * 100, 2 )

$_ChannelElement_LimitingChannel = "<result>
                                        <channel>{0}</channel>
                                        <value>{1}</value>
                                        <Unit>{2}</Unit>
                                        <float>{3}</float>
                                        <LimitMinWarning>{4}</LimitMinWarning>
                                        <LimitMinError>{5}</LimitMinError>
                                        <LimitMode>1</LimitMode>
                                    </result>"

$_ChannelElement_GeneralChannel = "<result>
                                        <channel>{0}</channel>
                                        <value>{1}</value>
                                        <Unit>{2}</Unit>
                                        <CustomUnit>{3}</CustomUnit>
                                        <float>{4}</float>
                                </result>"

($_ChannelElement_LimitingChannel -f "Percent Available Memory", $PercentAvailable, "Percent", 1, 20, 10)
($_ChannelElement_GeneralChannel -f "Available Memory", $AvailableMemory, "Custom", "GB", 1)
($_ChannelElement_GeneralChannel -f "Current Memory Usage", $CurrentUsedMemoryInGB, "Custom", "GB", 1)
($_ChannelElement_GeneralChannel -f "Max Avaialble Memory", $MaxAvailableMemoryInGB, "Custom", "GB", 1)
($_ChannelElement_GeneralChannel -f "Max Avaialble Memory", $MaxAvailableMemoryInGB, "Custom", "GB", 1)

"</prtg>"
exit 0