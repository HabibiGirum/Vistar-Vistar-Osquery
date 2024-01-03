# Define the osquery queries and their simplified names as a hashtable

$osqueryQueries = @{
    "SELECT REPLACE(CONCAT(hostname, '-', uuid), '-', '_') AS uniqueId FROM system_info;" = "uniqueId"
    "SELECT name, version FROM os_version;" = "os_version"
    "SELECT name FROM programs WHERE name LIKE '%avast%' OR name LIKE '%antivirus%';" = "antivirus_programs"
    "SELECT CASE WHEN protection_status = 0 THEN 'Hard drive not encrypted' ELSE 'Hard drive encrypted' END AS encryption_status FROM bitlocker_info LIMIT 1;" = "bitlocker_status"
    "SELECT CASE WHEN name IN ('LastPass', '1Password', 'Bitwarden', 'Dashlane', 'Keeper', 'RoboForm', 'NordPass', 'Enpass', 'Sticky Password', 'Password Safe', 'Myki', 'RememBear') THEN name ELSE 'No password manager in use' END AS password_manager FROM programs WHERE name IN ('LastPass', '1Password', 'Bitwarden', 'Dashlane', 'Keeper', 'RoboForm', 'NordPass', 'Enpass', 'Sticky Password', 'Password Safe', 'Myki', 'RememBear') UNION SELECT 'No password manager in use' AS password_manager WHERE (SELECT COUNT(*) FROM programs WHERE name IN ('LastPass', '1Password', 'Bitwarden', 'Dashlane', 'Keeper', 'RoboForm', 'NordPass', 'Enpass', 'Sticky Password', 'Password Safe', 'Myki', 'RememBear')) = 0;" = "password_manager"
    "SELECT username FROM users WHERE directory LIKE 'C:\\Users\\%';" = "usernames"
    "SELECT name, data FROM registry WHERE key = 'HKEY_CURRENT_USER\\Control Panel\\Desktop' AND (name = 'ScreenSaveActive' OR name = 'ScreenSaverIsSecure');" = "screen_lock"
}

# Define the API endpoint where you want to send the data
$endpointUrl = "https://api.vistar.cloud/api/v1/computers/osquery_log_data/"

# Specify the interval (in seconds) between data sends (e.g., every 1 hour)
$intervalSeconds = 3600  # 1 hour

while ($true) {
    # Initialize an empty hashtable to store the results of all queries
    $allOsqueryData = @{}

    # Run each osquery query and capture the output
    foreach ($query in $osqueryQueries.GetEnumerator()) {
        $queryText = $query.Key
        $simplifiedName = $query.Value

        try {
            $osqueryOutput = & 'C:\Program Files\osquery\osqueryi.exe' "--json" $queryText
            $osqueryData = $osqueryOutput | ConvertFrom-Json
            $allOsqueryData[$simplifiedName] = $osqueryData
        }
        catch {
            Write-Host "Error running osquery for query '$queryText': $_"
        }
    }

    # Send the combined data to the endpoint using the Invoke-RestMethod cmdlet
    try {
        $response = Invoke-RestMethod -Uri $endpointUrl -Method Post -Body ($allOsqueryData | ConvertTo-Json) -ContentType 'application/json'

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