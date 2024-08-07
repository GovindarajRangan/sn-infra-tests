# Input and output CSV file paths
$inputFile = "C:\Users\azadmin\Desktop\Finalized-Scripts\Connectivity\Connectivty-Input.csv"
$outputFile = "C:\Users\azadmin\Desktop\Finalized-Scripts\Connectivity\Connectivity-Output.csv"

# Import the input CSV file
$entries = Import-Csv -Path $inputFile

# Store the results
$jobs = @()

# Run the port checks as jobs
foreach ($entry in $entries) {
    $runsOn = $entry.Source  # Set RunsOn to be the same as Source
    $source = $entry.Source
    $destination = $entry.Destination
    $port = [int]$entry.Port
    $expectedResult = $entry.'Expected Result'

    # Validate input parameters
    if ([string]::IsNullOrEmpty($runsOn) -or [string]::IsNullOrEmpty($source) -or [string]::IsNullOrEmpty($destination) -or -not $port) {
        Write-Error "Invalid input parameter for entry: $entry"
        continue
    }

    $job = Start-Job -ScriptBlock {
        param ($runsOn, $source, $destination, $port, $expectedResult)

        $scriptBlock = {
            param ($destination, $port)

            function Test-Port {
                param (
                    [string]$IPAddress,
                    [int]$Port
                )

                try {
                    $result = Test-NetConnection -ComputerName $IPAddress -Port $Port -WarningAction SilentlyContinue -ErrorAction SilentlyContinue

                    if ($result.TcpTestSucceeded) {
                        return "Success"
                    } else {
                        return "Failed"
                    }
                } catch {
                    return "Error"
                }
            }

            $status = Test-Port -IPAddress $destination -Port $port
            $result = [PSCustomObject]@{
                RunsOn = $using:runsOn
                Source = $using:source
                Destination = $destination
                Port = $port
                'Expected Result' = $using:expectedResult
                'Test Result' = $status
            }

            return $result
        }

        # Check the port connectivity from the source to the destination IP and port
        $remoteResult = Invoke-Command -ComputerName $source -ScriptBlock $scriptBlock -ArgumentList $destination, $port

        $remoteResult
    } -ArgumentList $runsOn, $source, $destination, $port, $expectedResult
    $jobs += $job
}

# Wait for all jobs to complete
$jobs | ForEach-Object { $_ | Wait-Job }

# Collect the results
$results = $jobs | ForEach-Object {
    $job = Receive-Job -Job $_
    Remove-Job -Job $_
    $job
}

# Export results to the output CSV file
$results | Select-Object RunsOn, Source, Destination, Port, 'Expected Result', 'Test Result' | Export-Csv -Path $outputFile -NoTypeInformation

Write-Output "Port check completed. Results saved to $outputFile"
