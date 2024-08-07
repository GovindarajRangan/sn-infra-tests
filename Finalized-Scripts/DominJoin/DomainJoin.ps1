# Define the input and output CSV file paths
$inputCSV = "C:\Users\azadmin\Desktop\Finalized-Scripts\DominJoin\DomainJoin-Input.csv"
$outputCSV = "C:\Users\azadmin\Desktop\Finalized-Scripts\DominJoin\DomainJoin-Output.csv"

# Import the input CSV
$inputData = Import-Csv -Path $inputCSV

# Initialize an array to store the output data
$outputData = @()

# Function to check domain join status
$GetDomainJoinStatusScript = @"
function Get-DomainJoinStatus {
    param (
        [string]`$ComputerName
    )

    try {
        `$computerSystem = Get-WmiObject -Class Win32_ComputerSystem -ComputerName `$ComputerName
        if (`$computerSystem.PartOfDomain) {
            return "Joined"
        } else {
            return "Not Joined"
        }
    } catch {
        return "Not Joined"
    }
}
"@

# Initialize a collection to hold the jobs
$jobs = @()

# Iterate over each row in the input CSV and create a job for each domain join check
foreach ($row in $inputData) {
    $jobs += Start-Job -ScriptBlock {
        param ($row, $GetDomainJoinStatusScript)

        # Define the function in the job's scope
        Invoke-Expression $GetDomainJoinStatusScript

        # Get domain join status
        $testResult = Get-DomainJoinStatus -ComputerName $row.ComputerName

        # Return the result as a custom object
        return [PSCustomObject]@{
            RunsOn         = $row.ComputerName
            ComputerName   = $row.ComputerName
            ExpectedResult = $row.ExpectedResult
            TestResult     = $testResult
        }
    } -ArgumentList $row, $GetDomainJoinStatusScript
}

# Wait for all jobs to complete
$jobs | Wait-Job

# Retrieve the results from the jobs and add them to the output data
foreach ($job in $jobs) {
    $outputData += Receive-Job -Job $job
    Remove-Job -Job $job
}

# Select only the desired columns and export to CSV
$outputData | Select-Object RunsOn, ComputerName, ExpectedResult, TestResult | Export-Csv -Path $outputCSV -NoTypeInformation

Write-Host "Domain join status check completed. Results saved to $outputCSV"
