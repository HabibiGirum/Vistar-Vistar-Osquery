# Define osquery queries and their simplified names as a hashtable
$osqueryQueries = @{
    "SELECT REPLACE(CONCAT(hostname, '-', uuid), '-', '_') AS uniqueId FROM system_info;" = "uniqueId"
    "SELECT name, version FROM os_version;" = "os_version"
    "SELECT name FROM programs WHERE name LIKE '%avast%' OR name LIKE '%antivirus%';" = "antivirus_programs"
    # ... add more queries as needed
}

# API endpoint where you want to send the data
$endpointUrl = "https://api.vistar.cloud/api/v1/computers/osquery_log_data/"

# Interval between data sends (e.g., every 1 hour)
$intervalSeconds = 3600

while ($true) {
    # Initialize an empty hashtable to store the results of all queries
    $allOsqueryData = @{}

    # Run each osquery query and capture the output
    foreach ($query in $osqueryQueries.Keys) {
        try {
            $osqueryOutput = & "C:\Program Files\osquery\osqueryi.exe" "--json" $query
            $osqueryData = $osqueryOutput | ConvertFrom-Json
            $allOsqueryData[$osqueryQueries[$query]] = $osqueryData
        }
        catch {
            Write-Host "Error running osquery for query '$query': $_"
        }
    }

    # Send the combined data to the endpoint using the Invoke-RestMethod cmdlet
    try {
        $headers = @{
            "Content-Type" = "application/json"
        }
        $response = Invoke-RestMethod -Uri $endpointUrl -Method Post -Body ($allOsqueryData | ConvertTo-Json) -Headers $headers

        if ($response.StatusCode -eq 201) {
            Write-Host "Data sent successfully. Status code: 201"
        }
        else {
            Write-Host "Failed to send data. Status code: $($response.StatusCode)"
        }
    }
    catch {
        Write-Host "Error sending data: $_"
    }

    # Sleep for the specified interval before the next run
    Start-Sleep -Seconds $intervalSeconds
}
