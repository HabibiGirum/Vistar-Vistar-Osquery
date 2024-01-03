# Define the osquery queries and their simplified names as a hashtable
$osqueryQueries = @{
    "SELECT REPLACE(CONCAT(hostname, '-', uuid), '-', '_') AS uniqueId FROM system_info;" = "uniqueId";
    "SELECT name, version FROM os_version;" = "os_version";
    "SELECT name FROM programs WHERE name LIKE '%avast%' OR name LIKE '%antivirus%';" = "antivirus_programs";
    "SELECT CASE WHEN protection_status = 0 THEN 'Hard drive not encrypted' ELSE 'Hard drive encrypted' END AS encryption_status FROM bitlocker_info LIMIT 1;" = "bitlocker_status";
    "SELECT CASE WHEN name IN ('LastPass', '1Password', 'Bitwarden', 'Dashlane', 'Keeper', 'RoboForm', 'NordPass', 'Enpass', 'Sticky Password', 'Password Safe', 'Myki', 'RememBear') THEN name ELSE 'No password manager in use' END AS password_manager FROM programs WHERE name IN ('LastPass', '1Password', 'Bitwarden', 'Dashlane', 'Keeper', 'RoboForm', 'NordPass', 'Enpass', 'Sticky Password', 'Password Safe', 'Myki', 'RememBear') UNION SELECT 'No password manager in use' AS password_manager WHERE (SELECT COUNT(*) FROM programs WHERE name IN ('LastPass', '1Password', 'Bitwarden', 'Dashlane', 'Keeper', 'RoboForm', 'NordPass', 'Enpass', 'Sticky Password', 'Password Safe', 'Myki', 'RememBear')) = 0;" = "password_manager";
    "SELECT username FROM users WHERE directory LIKE 'C:\\Users\\%';" = "usernames";
    "SELECT name, data FROM registry WHERE key = 'HKEY_CURRENT_USER\\Control Panel\\Desktop' AND (name = 'ScreenSaveActive' OR name = 'ScreenSaverIsSecure');" = "screen Lock";
}

# Define the API endpoint
$endpointUrl = "https://api.vistar.cloud/api/v1/computers/osquery_log_data/"

# Specify the interval (in seconds)
$intervalSeconds = 3600

while ($true) {
    # Initialize an empty hashtable to store results
    $allOsqueryData = @{}

    # Run each osquery query and capture output
    foreach ($query in $osqueryQueries.Keys) {
        try {
            $osqueryOutput = Invoke-Expression -Command "C:\Program Files\osquery\osqueryi.exe --json $query"
            $osqueryData = ConvertFrom-Json $osqueryOutput
            $allOsqueryData[$osqueryQueries[$query]] = $osqueryData
        } catch {
            Write-Error "Error running osquery for query '$query': $_"
        }
    }

    try {
        # Send the combined data to the endpoint
        $response = Invoke-RestMethod -Method Post -Uri $endpointUrl -Body $allOsqueryData -ContentType "application/json"
        if ($response.StatusCode -eq 201) {
            Write-Host "Data sent successfully. Status code: 201"
        } else {
            Write-Warning "Failed to send data. Status code: $($response.StatusCode)"
        }
    } catch {
        Write-Error "Error sending data: $_"
    }

    # Sleep for the specified interval
    Start-Sleep -Seconds $intervalSeconds
}
