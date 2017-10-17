<#
    .SYNOPSIS
    This monitor will get the performance statistics of a cluster physical disk.
    .PARAMETER ClusterName
    The name of the cluster handling the disks.
    .PARAMETER VolumeLabel
    The label of the disk that we want to get statistics for
    .PARAMETER sensorID
    The sensorID that triggered the script. This parameter will be a PRTG placeholder.
    .PARAMETER PRTGServer
    The Prtg Server URL
    .PARAMETER ApiUsername
    The username that will be used to perform the API calls.
    .PARAMETER PRTGServer
    The password hash that will be used to perform the API calls.
    .NOTES
    This function will require a 'mock' device to be created for the Cluster with the name of the cluster. The cmdlet will use the 'VolumeLabel' 
    of the drive, and will gather information based on that. If the label is not unique, or there is cloned drives this function will fail for those devices.
    
    You'll need to create a new Sensor with the name 'Disk Statistics - VolumeLabel', the sensor must use proper Windows credentials that can run WMI queries
    on the cluster machines, and use the following execparams_:

    -ClusterName %host -VolumeLabel volumelabelhere -sensorID %sensorid

    The script will then modify the name of the sensor to include the current node where the volume is located, and will gather statistics base on that node.     
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory, Position=0)]
    [string]
    $ClusterName,
    [Parameter(Mandatory, Position=1)]
    [string]
    $VolumeLabel,
    [Parameter(Mandatory, Position=2)]
    [string]
    $sensorID,
    # Parameter help description
    [Parameter(Mandatory, Position=3)]
    [String]
    $PRTGServer,
    # Parameter help description
    [Parameter(Mandatory, Position=4)]
    [String]
    $ApiUsername,
    # Parameter help description
    [Parameter(Mandatory, Position=5)]
    [Int64]
    $ApiPasswordHash
)


$SC_clusterNodes = [ScriptBlock] {
    param($diskName, $clusterName)

    Get-Module FailoverClusters -ListAvailable | Import-Module
    $cluster = Get-Cluster -Name $clusterName
    $clusterDisk = Get-ClusterResource -Cluster $cluster -Name $diskName | Where-Object { $_.ResourceType -eq 'Physical Disk' }

    if(!($clusterDisk)){

        "Unable to the disk $($diskName) in the load balancer"
        exit 2
    }


    if($clusterDisk.getType().Name -eq 'Object[]'){
        "Found multiple disks with the name $($diskName) in the load balancer."
        exit 2
    }

    try {
        $clusterResource = Get-WmiObject -ComputerName $clusterDisk.OwnerGroup.Name -Namespace root/mscluster -Class MSCluster_Resource -Filter ("Name='" + $diskName + "'") -ErrorAction Stop
        $diskPartition = Get-WmiObject -ComputerName $clusterDisk.OwnerGroup.Name -Namespace root/mscluster -Query "ASSOCIATORS OF {$clusterResource} WHERE ResultClass = MSCluster_DiskPartition" -ErrorAction Stop        
    }
    catch {
        "Unable to gather disks from the cluster."
        exit 2
    }

    $allDisksStats = Get-WmiObject -ComputerName $clusterDisk.OwnerGroup.name -Class win32_perfformatteddata_perfdisk_logicaldisk 

    $performanceStatistics = $allDisksStats | Where-Object { $_.Name -eq $diskPartition.MountPoints[0]}

    if(!($performanceStatistics)) {
        "Unable to find statistics for $($diskName) in $($clusterDisk.OwnerGroup.Name)."
        exit 2
    }

    $returningObj = New-Object psobject
    $returningObj | Add-Member -MemberType NoteProperty -Name "OwnerGroup"              -Value $clusterDisk.OwnerGroup.Name
    $returningObj | Add-Member -MemberType NoteProperty -Name "AvgDiskBytesPerRead"     -Value $performanceStatistics.AvgDiskBytesPerRead
    $returningObj | Add-Member -MemberType NoteProperty -Name "AvgDiskBytesPerTransfer" -Value $performanceStatistics.AvgDiskBytesPerTransfer
    $returningObj | Add-Member -MemberType NoteProperty -Name "AvgDiskBytesPerWrite"    -Value $performanceStatistics.AvgDiskBytesPerWrite
    $returningObj | Add-Member -MemberType NoteProperty -Name "AvgDiskQueueLength"      -Value $performanceStatistics.AvgDiskQueueLength
    $returningObj | Add-Member -MemberType NoteProperty -Name "AvgDiskReadQueueLength"  -Value $performanceStatistics.AvgDiskReadQueueLength
    $returningObj | Add-Member -MemberType NoteProperty -Name "AvgDisksecPerRead"       -Value $performanceStatistics.AvgDisksecPerRead
    $returningObj | Add-Member -MemberType NoteProperty -Name "AvgDisksecPerTransfer"   -Value $performanceStatistics.AvgDisksecPerTransfer
    $returningObj | Add-Member -MemberType NoteProperty -Name "AvgDisksecPerWrite"      -Value $performanceStatistics.AvgDisksecPerWrite
    $returningObj | Add-Member -MemberType NoteProperty -Name "AvgDiskWriteQueueLength" -Value $performanceStatistics.AvgDiskWriteQueueLength
    $returningObj | Add-Member -MemberType NoteProperty -Name "CurrentDiskQueueLength"  -Value $performanceStatistics.CurrentDiskQueueLength
    $returningObj | Add-Member -MemberType NoteProperty -Name "DiskBytesPersec"         -Value $performanceStatistics.DiskBytesPersec
    $returningObj | Add-Member -MemberType NoteProperty -Name "DiskReadBytesPersec"     -Value $performanceStatistics.DiskReadBytesPersec
    $returningObj | Add-Member -MemberType NoteProperty -Name "DiskReadsPersec"         -Value $performanceStatistics.DiskReadsPersec
    $returningObj | Add-Member -MemberType NoteProperty -Name "DiskTransfersPersec"     -Value $performanceStatistics.DiskTransfersPersec
    $returningObj | Add-Member -MemberType NoteProperty -Name "DiskWriteBytesPersec"    -Value $performanceStatistics.DiskWriteBytesPersec
    $returningObj | Add-Member -MemberType NoteProperty -Name "DiskWritesPersec"        -Value $performanceStatistics.DiskWritesPersec
    $returningObj | Add-Member -MemberType NoteProperty -Name "FreeSpace"               -Value ([Math]::Round("$($performanceStatistics.FreeMegabytes)MB"/1GB, 2))
    $returningObj | Add-Member -MemberType NoteProperty -Name "PercentDiskReadTime"     -Value $performanceStatistics.PercentDiskReadTime
    $returningObj | Add-Member -MemberType NoteProperty -Name "PercentDiskTime"         -Value $performanceStatistics.PercentDiskTime
    $returningObj | Add-Member -MemberType NoteProperty -Name "PercentDiskWriteTime"    -Value $performanceStatistics.PercentDiskWriteTime
    $returningObj | Add-Member -MemberType NoteProperty -Name "PercentFreeSpace"        -Value $performanceStatistics.PercentFreeSpace
    $returningObj | Add-Member -MemberType NoteProperty -Name "PercentIdleTime"         -Value $performanceStatistics.PercentIdleTime
    $returningObj | Add-Member -MemberType NoteProperty -Name "SplitIOPerSec"           -Value $performanceStatistics.SplitIOPerSec
    $returningObj | Add-Member -MemberType NoteProperty -Name "TotalSize"               -Value ([Math]::Round("$($diskPartition.TotalSize)MB"/1GB, 2))

    $returningObj
    exit 0
}
$results = & "$env:windir\sysnative\WindowsPowerShell\v1.0\powershell.exe" -command $SC_clusterNodes -args $VolumeLabel, $ClusterName

if($LASTEXITCODE -eq 0) {
    $properSensorName = ("Disk Statistics - {0} - {1}" -f $VolumeLabel.ToUpper(), $results.OwnerGroup.ToUpper())
    $URI_getSensorName = ("http://{0}/api/getobjectproperty.htm?id={1}&name=name&show=text&username={2}&passhash={3}" -f $PRTGServer, $sensorID, $ApiUsername, $ApiPasswordHash)
    $getSensorProperties = Invoke-RestMethod -Method Get -Uri $URI_getSensorName

    if(!($getSensorProperties.prtg.result.Equals($properSensorName))){
        $URI_SetSensorName = ("http://{0}/api/setobjectproperty.htm?id={1}&name=name&value={2}&username={3}&passhash={4}" -f $PRTGServer, $sensorID, $properSensorName, $ApiUsername, $ApiPasswordHash)
        Invoke-RestMethod -Method GeT -Uri $URI_SetSensorName | Out-Null
    }

    #region Output
    '<?xml version="1.0" encoding="Windows-1252" ?>'
    "<prtg>"
    ("<result>
        <channel>{0}</channel>
        <value>{1}</value>
        <Unit>{2}</Unit>
        <CustomUnit>{3}</CustomUnit>
        <float>1</float>
        <LimitMinWarning>15</LimitMinWarning>
        <LimitMinError>8</LimitMinError>
        <LimitMode>1</LimitMode>
    </result>"                          -f 'PercentFreeSpace', $results.PercentFreeSpace, "Custom", "%" ) 
    ("<result>
        <channel>{0}</channel>
        <value>{1}</value>
        <Unit>{2}</Unit>
        <CustomUnit>{3}</CustomUnit>
        <float>1</float>
    </result>"                          -f 'AvgDiskBytesPerRead', $results.AvgDiskBytesPerRead, "Custom", "" ) 
    ("<result>
        <channel>{0}</channel>
        <value>{1}</value>
        <Unit>{2}</Unit>
        <CustomUnit>{3}</CustomUnit>
        <float>1</float>
    </result>"                          -f 'AvgDiskBytesPerTransfer', $results.AvgDiskBytesPerTransfer, "Custom", "" ) 
    ("<result>
        <channel>{0}</channel>
        <value>{1}</value>
        <Unit>{2}</Unit>
        <CustomUnit>{3}</CustomUnit>
        <float>1</float>
    </result>"                          -f 'AvgDiskBytesPerWrite', $results.AvgDiskBytesPerWrite, "Custom", "" ) 
    ("<result>
        <channel>{0}</channel>
        <value>{1}</value>
        <Unit>{2}</Unit>
        <CustomUnit>{3}</CustomUnit>
        <float>1</float>
    </result>"                          -f 'AvgDiskQueueLength', $results.AvgDiskQueueLength, "Custom", "" ) 
    ("<result>
        <channel>{0}</channel>
        <value>{1}</value>
        <Unit>{2}</Unit>
        <CustomUnit>{3}</CustomUnit>
        <float>1</float>
    </result>"                          -f 'AvgDiskReadQueueLength', $results.AvgDiskReadQueueLength, "Custom", "" ) 
    ("<result>
        <channel>{0}</channel>
        <value>{1}</value>
        <Unit>{2}</Unit>
        <CustomUnit>{3}</CustomUnit>
        <float>1</float>
    </result>"                          -f 'AvgDisksecPerRead', $results.AvgDisksecPerRead, "Custom", "" ) 
    ("<result>
        <channel>{0}</channel>
        <value>{1}</value>
        <Unit>{2}</Unit>
        <CustomUnit>{3}</CustomUnit>
        <float>1</float>
    </result>"                          -f 'AvgDisksecPerTransfer', $results.AvgDisksecPerTransfer, "Custom", "" ) 
    ("<result>
        <channel>{0}</channel>
        <value>{1}</value>
        <Unit>{2}</Unit>
        <CustomUnit>{3}</CustomUnit>
        <float>1</float>
    </result>"                          -f 'AvgDisksecPerWrite', $results.AvgDisksecPerWrite, "Custom", "" ) 
    ("<result>
        <channel>{0}</channel>
        <value>{1}</value>
        <Unit>{2}</Unit>
        <CustomUnit>{3}</CustomUnit>
        <float>1</float>
    </result>"                          -f 'AvgDiskWriteQueueLength', $results.AvgDiskWriteQueueLength, "Custom", "" ) 
    ("<result>
        <channel>{0}</channel>
        <value>{1}</value>
        <Unit>{2}</Unit>
        <CustomUnit>{3}</CustomUnit>
        <float>1</float>
    </result>"                          -f 'CurrentDiskQueueLength', $results.CurrentDiskQueueLength, "Custom", "" ) 
    ("<result>
        <channel>{0}</channel>
        <value>{1}</value>
        <Unit>{2}</Unit>
        <CustomUnit>{3}</CustomUnit>
        <float>1</float>
    </result>"                          -f 'DiskBytesPersec', $results.DiskBytesPersec, "Custom", "" ) 
    ("<result>
        <channel>{0}</channel>
        <value>{1}</value>
        <Unit>{2}</Unit>
        <CustomUnit>{3}</CustomUnit>
        <float>1</float>
    </result>"                          -f 'DiskReadBytesPersec', $results.DiskReadBytesPersec, "Custom", "" ) 
    ("<result>
        <channel>{0}</channel>
        <value>{1}</value>
        <Unit>{2}</Unit>
        <CustomUnit>{3}</CustomUnit>
        <float>1</float>
    </result>"                          -f 'DiskReadsPersec', $results.DiskReadsPersec, "Custom", "" ) 
    ("<result>
        <channel>{0}</channel>
        <value>{1}</value>
        <Unit>{2}</Unit>
        <CustomUnit>{3}</CustomUnit>
        <float>1</float>
    </result>"                          -f 'DiskTransfersPersec', $results.DiskTransfersPersec, "Custom", "" ) 
    ("<result>
        <channel>{0}</channel>
        <value>{1}</value>
        <Unit>{2}</Unit>
        <CustomUnit>{3}</CustomUnit>
        <float>1</float>
    </result>"                          -f 'DiskWriteBytesPersec', $results.DiskWriteBytesPersec, "Custom", "" ) 
    ("<result>
        <channel>{0}</channel>
        <value>{1}</value>
        <Unit>{2}</Unit>
        <CustomUnit>{3}</CustomUnit>
        <float>1</float>
    </result>"                          -f 'DiskWritesPersec', $results.DiskWritesPersec, "Custom", "" ) 
    ("<result>
        <channel>{0}</channel>
        <value>{1}</value>
        <Unit>{2}</Unit>
        <CustomUnit>{3}</CustomUnit>
        <float>1</float>
    </result>"                          -f 'FreeSpace', $results.FreeSpace, "Custom", "GB" ) 
    ("<result>
        <channel>{0}</channel>
        <value>{1}</value>
        <Unit>{2}</Unit>
        <CustomUnit>{3}</CustomUnit>
        <float>1</float>
    </result>"                          -f 'PercentDiskReadTime', $results.PercentDiskReadTime, "Custom", "%" ) 
    ("<result>
        <channel>{0}</channel>
        <value>{1}</value>
        <Unit>{2}</Unit>
        <CustomUnit>{3}</CustomUnit>
        <float>1</float>
    </result>"                          -f 'PercentDiskTime', $results.PercentDiskTime, "Custom", "%" ) 
    ("<result>
        <channel>{0}</channel>
        <value>{1}</value>
        <Unit>{2}</Unit>
        <CustomUnit>{3}</CustomUnit>
        <float>1</float>
    </result>"                          -f 'PercentDiskWriteTime', $results.PercentDiskWriteTime, "Custom", "%" ) 
    ("<result>
        <channel>{0}</channel>
        <value>{1}</value>
        <Unit>{2}</Unit>
        <CustomUnit>{3}</CustomUnit>
        <float>1</float>
    </result>"                          -f 'PercentIdleTime', $results.PercentIdleTime, "Custom", "%" ) 
    ("<result>
        <channel>{0}</channel>
        <value>{1}</value>
        <Unit>{2}</Unit>
        <CustomUnit>{3}</CustomUnit>
        <float>1</float>
    </result>"                          -f 'SplitIOPerSec', $results.SplitIOPerSec, "Custom", "" ) 
    ("<result>
        <channel>{0}</channel>
        <value>{1}</value>
        <Unit>{2}</Unit>
        <CustomUnit>{3}</CustomUnit>
        <float>1</float>
    </result>"                          -f 'Drive Size', $results.TotalSize, "Custom", "GB" ) 
    "</prtg>"
    #endregion
    exit 0

}
else {
    '<?xml version="1.0" encoding="Windows-1252" ?>'
    "<prtg>"
    "<Text>$result</Text>"
    "<Error>1</Error>"
    "</prtg>"
    exit $LASTEXITCODE
}