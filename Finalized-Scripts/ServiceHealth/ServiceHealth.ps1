# Function to map service status code to status name
function Get-ServiceStatusName {
    param (
        [int]$statusCode
    )

    switch ($statusCode) {
        1 { return "Stopped" }
        2 { return "StartPending" }
        3 { return "StopPending" }
        4 { return "Running" }
        5 { return "ContinuePending" }
        6 { return "PausePending" }
        7 { return "Paused" }
        default { return "Unknown" }
    }
}

# Import the CSV file containing the service status check information
$inputFilePath = "C:\Users\azadmin\Desktop\Finalized-Scripts\ServiceHealth\ServiceHealth-Input.csv"
$outputFilePath = "C:\Users\azadmin\Desktop\Finalized-Scripts\ServiceHealth\ServiceHealth-Output.csv"

Write-Host "Importing data from $inputFilePath"
$inputData = Import-Csv -Path $inputFilePath

# Initialize an array to hold the job objects
$jobs = @()

# Loop through each entry in the input CSV
foreach ($entry in $inputData) {
    $server = $entry.RunsOn
    $serviceName = $entry."Service Name"
    $expectedStatus = $entry."Expected Status"
    
    Write-Host "Starting job for server: $server, service: $serviceName"
    
    # Start a job to check the service status on the remote server
    $job = Start-Job -ScriptBlock {
        param($server, $serviceName, $expectedStatus)
        
        # Define the function within the script block
        function Get-ServiceStatusName {
            param (
                [int]$statusCode
            )

            switch ($statusCode) {
                1 { return "Stopped" }
                2 { return "StartPending" }
                3 { return "StopPending" }
                4 { return "Running" }
                5 { return "ContinuePending" }
                6 { return "PausePending" }
                7 { return "Paused" }
                default { return "Unknown" }
            }
        }

        $result = [PSCustomObject]@{
            "RunsOn"         = $server
            "Service Name"   = $serviceName
            "Expected Status" = $expectedStatus
            "Test Status"    = ""
            "Error Message"  = ""
        }
        
        try {
            # Use Invoke-Command to run the Get-Service command on the remote server
            $scriptBlock = {
                param($serviceName)
                try {
                    $service = Get-Service -Name $serviceName -ErrorAction Stop
                    return $service.Status
                } catch {
                    throw $_.Exception.Message
                }
            }
            
            $serviceStatus = Invoke-Command -ComputerName $server -ScriptBlock $scriptBlock -ArgumentList $serviceName -ErrorAction Stop
            
            # Map the service status code to status name
            $serviceStatusName = Get-ServiceStatusName -statusCode $serviceStatus
            
            # Check if the service status matches the expected status
            if ($serviceStatusName -eq $expectedStatus) {
                $result."Test Status" = "Pass"
            } else {
                $result."Test Status" = "Fail"
                $result."Error Message" = "Service status is $serviceStatusName instead of $expectedStatus."
            }
        } catch {
            $errorMsg = $_.Exception.Message
            Write-Host "Error checking service ${serviceName} on server ${server}: ${errorMsg}"
            $result."Test Status" = "Fail"
            $result."Error Message" = $errorMsg
        }
        
        return $result
    } -ArgumentList $server, $serviceName, $expectedStatus
    
    # Add the job object to the array
    $jobs += $job
}

Write-Host "Waiting for all jobs to complete..."
# Wait for all jobs to complete
$jobs | ForEach-Object { $_ | Wait-Job }

# Initialize an array to hold the output data
$outputData = @()

# Collect the results from each job
foreach ($job in $jobs) {
    $result = Receive-Job -Job $job
    $outputData += $result
    # Remove the completed job
    Remove-Job -Job $job
}

# Check if there is any output data before attempting to export
if ($outputData) {
    # Sort the output data to ensure the order of columns is correct
    $sortedOutputData = $outputData | Select-Object "RunsOn", "Service Name", "Expected Status", "Test Status", "Error Message"
    
    Write-Host "Exporting data to $outputFilePath"
    # Export the output data to a CSV file
    $sortedOutputData | Export-Csv -Path $outputFilePath -NoTypeInformation
    Write-Host "Data successfully exported."
} else {
    Write-Host "No data collected. Please check the input data and try again."
}
