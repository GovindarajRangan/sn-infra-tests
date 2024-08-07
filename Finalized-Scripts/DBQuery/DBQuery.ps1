# Load the CSV file
$inputFile = "C:\Users\azadmin\Desktop\Finalized-Scripts\DBQuery\DBQuery-Input.csv"
$inputData = Import-Csv -Path $inputFile

# Function to check the database query
function Test-DBQuery {
    param (
        [string]$RunsOn,
        [string]$DBType,
        [string]$DBConnectionString,
        [string]$SampleQuery,
        [string]$ExpectedOutput
    )

    # Initialize the result
    $result = @{
        RunsOn             = $RunsOn
        DBType             = $DBType
        DBConnectionString = $DBConnectionString
        SampleQuery        = $SampleQuery
        ExpectedOutput     = $ExpectedOutput
        TestResult         = "Failed"
        ActualOutput       = ""
        Error              = ""
    }

    try {
        if ($DBType -eq "MSSQL") {
            # Create a SQL connection
            $connection = New-Object System.Data.SqlClient.SqlConnection
            $connection.ConnectionString = $DBConnectionString
            
            Write-Host "Attempting to open connection to $RunsOn using connection string: $DBConnectionString"
            $connection.Open()

            Write-Host "Connection opened successfully. Executing query on $RunsOn"
            # Create a SQL command
            $command = $connection.CreateCommand()
            $command.CommandText = $SampleQuery

            # Execute the command and get the result
            $reader = $command.ExecuteReader()
            $output = ""
            while ($reader.Read()) {
                $output += $reader[0].ToString() + " "
            }
            $output = $output.Trim()
            $reader.Close()
            $connection.Close()

            # Update the result
            if ($output -eq $ExpectedOutput) {
                $result.TestResult = "Passed"
            }
            $result.ActualOutput = $output
        }
        else {
            Write-Host "Unsupported DB Type: $DBType"
            $result.Error = "Unsupported DB Type: $DBType"
        }
    }
    catch {
        Write-Host "Error executing query on $RunsOn using connection string: $DBConnectionString"
        Write-Host "Error: $($_.Exception.Message)"
        $result.Error = $_.Exception.Message
    }

    return $result
}

# Initialize the results array
$results = @()

# Start jobs for each row in the input data
$jobs = @()
foreach ($row in $inputData) {
    $job = Start-Job -ScriptBlock {
        param (
            $RunsOn,
            $DBType,
            $DBConnectionString,
            $SampleQuery,
            $ExpectedOutput
        )

        function Test-DBQuery {
            param (
                [string]$RunsOn,
                [string]$DBType,
                [string]$DBConnectionString,
                [string]$SampleQuery,
                [string]$ExpectedOutput
            )

            # Initialize the result
            $result = @{
                RunsOn             = $RunsOn
                DBType             = $DBType
                DBConnectionString = $DBConnectionString
                SampleQuery        = $SampleQuery
                ExpectedOutput     = $ExpectedOutput
                TestResult         = "Failed"
                ActualOutput       = ""
                Error              = ""
            }

            try {
                if ($DBType -eq "MSSQL") {
                    # Create a SQL connection
                    $connection = New-Object System.Data.SqlClient.SqlConnection
                    $connection.ConnectionString = $DBConnectionString
                    
                    Write-Host "Attempting to open connection to $RunsOn using connection string: $DBConnectionString"
                    $connection.Open()

                    Write-Host "Connection opened successfully. Executing query on $RunsOn"
                    # Create a SQL command
                    $command = $connection.CreateCommand()
                    $command.CommandText = $SampleQuery

                    # Execute the command and get the result
                    $reader = $command.ExecuteReader()
                    $output = ""
                    while ($reader.Read()) {
                        $output += $reader[0].ToString() + " "
                    }
                    $output = $output.Trim()
                    $reader.Close()
                    $connection.Close()

                    # Update the result
                    if ($output -eq $ExpectedOutput) {
                        $result.TestResult = "Passed"
                    }
                    $result.ActualOutput = $output
                }
                else {
                    Write-Host "Unsupported DB Type: $DBType"
                    $result.Error = "Unsupported DB Type: $DBType"
                }
            }
            catch {
                Write-Host "Error executing query on $RunsOn using connection string: $DBConnectionString"
                Write-Host "Error: $($_.Exception.Message)"
                $result.Error = $_.Exception.Message
            }

            return $result
        }

        Test-DBQuery -RunsOn $RunsOn -DBType $DBType -DBConnectionString $DBConnectionString -SampleQuery $SampleQuery -ExpectedOutput $ExpectedOutput
    } -ArgumentList $row.RunsOn, $row.DBType, $row.DBConnectionString, $row.SampleQuery, $row.ExpectedOutput
    $jobs += $job
}

# Wait for all jobs to complete and collect the results
foreach ($job in $jobs) {
    $jobResult = Receive-Job -Job $job -Wait
    $results += $jobResult
}

# Convert the results to a CSV file with the required columns
$outputFile = "C:\Users\azadmin\Desktop\Finalized-Scripts\DBQuery\DBQuery-Output.csv"
$results | Select-Object RunsOn, DBType, DBConnectionString, SampleQuery, ExpectedOutput, TestResult, ActualOutput, Error | Export-Csv -Path $outputFile -NoTypeInformation

Write-Host "DB query tests completed. Results saved to $outputFile."