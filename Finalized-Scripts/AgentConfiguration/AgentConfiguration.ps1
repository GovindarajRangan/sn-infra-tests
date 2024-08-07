# Define the path to the input CSV file
$inputCSVPath = "C:\path\to\input.csv"

# Define the path to the output CSV file
$outputCSVPath = "C:\path\to\output.csv"

# Import the input CSV file
$inputData = Import-Csv -Path $inputCSVPath

# Initialize an array to hold the jobs
$jobs = @()

# Iterate through each row in the input CSV and create a job for each row
foreach ($row in $inputData) {
    $RunsOn = $row.RunsOn
    $ToolName = $row.'Tool Name'
    $ConfigSignature = $row.'Config Signature'
    $Config = $row.Config
    $SignatureType = $row.'Signature Type'
    $ExpectedConfig = $row.'Expected Config'

    $job = Start-Job -ScriptBlock {
        param (
            $RunsOn,
            $ToolName,
            $ConfigSignature,
            $Config,
            $SignatureType,
            $ExpectedConfig
        )

        $Result = @{
            RunsOn = $RunsOn
            ToolName = $ToolName
            ConfigSignature = $ConfigSignature
            Config = $Config
            SignatureType = $SignatureType
            ExpectedConfig = $ExpectedConfig
            TestConfig = ""
            Status = ""
        }

        # Function to check the registry
        function Check-Registry {
            param (
                [string]$ConfigSignature,
                [string]$ExpectedConfig,
                [string]$RemoteComputer
            )
            try {
                $actualConfig = Invoke-Command -ComputerName $RemoteComputer -ScriptBlock {
                    Get-ItemProperty -Path $using:ConfigSignature
                }
                if ($actualConfig -eq $ExpectedConfig) {
                    return @("Success", $actualConfig)
                } else {
                    return @("Failed", $actualConfig)
                }
            } catch {
                return @("Failed", "")
            }
        }

        # Function to check file configuration
        function Check-FileConfig {
            param (
                [string]$ConfigSignature,
                [string]$ExpectedConfig,
                [string]$RemoteComputer
            )
            try {
                $actualConfig = Invoke-Command -ComputerName $RemoteComputer -ScriptBlock {
                    Get-Content -Path $using:ConfigSignature
                }
                if ($actualConfig -eq $ExpectedConfig) {
                    return @("Success", $actualConfig)
                } else {
                    return @("Failed", $actualConfig)
                }
            } catch {
                return @("Failed", "")
            }
        }

        # Function to check command line output
        function Check-CommandLine {
            param (
                [string]$ConfigSignature,
                [string]$ExpectedConfig,
                [string]$RemoteComputer
            )
            try {
                $actualConfig = Invoke-Command -ComputerName $RemoteComputer -ScriptBlock {
                    Invoke-Expression -Command $using:ConfigSignature
                }
                if ($actualConfig -eq $ExpectedConfig) {
                    return @("Success", $actualConfig)
                } else {
                    return @("Failed", $actualConfig)
                }
            } catch {
                return @("Failed", "")
            }
        }

        # Determine which check to perform based on the SignatureType
        switch ($SignatureType) {
            "Registry" {
                $Result.ActualConfig = Invoke-Command -ComputerName $RunsOn -ScriptBlock {
                    Get-ItemProperty -Path $using:ConfigSignature
                }
                $Result.Status, $Result.TestConfig = Check-Registry -ConfigSignature $ConfigSignature -ExpectedConfig $ExpectedConfig -RemoteComputer $RunsOn
            }
            "FileConfig" {
                $Result.ActualConfig = Invoke-Command -ComputerName $RunsOn -ScriptBlock {
                    Get-Content -Path $using:ConfigSignature
                }
                $Result.Status, $Result.TestConfig = Check-FileConfig -ConfigSignature $ConfigSignature -ExpectedConfig $ExpectedConfig -RemoteComputer $RunsOn
            }
            "CommandLine" {
                $Result.ActualConfig = Invoke-Command -ComputerName $RunsOn -ScriptBlock {
                    Invoke-Expression -Command $using:ConfigSignature
                }
                $Result.Status, $Result.TestConfig = Check-CommandLine -ConfigSignature $ConfigSignature -ExpectedConfig $ExpectedConfig -RemoteComputer $RunsOn
            }
        }

        return $Result

    } -ArgumentList $RunsOn, $ToolName, $ConfigSignature, $Config, $SignatureType, $ExpectedConfig

    $jobs += $job
}

# Wait for all jobs to complete and gather results
$outputData = @()
foreach ($job in $jobs) {
    $result = Receive-Job -Job $job
    $outputData += $result
    Remove-Job -Job $job
}

# Export the output data to the output CSV file
$outputData | Export-Csv -Path $outputCSVPath -NoTypeInformation
