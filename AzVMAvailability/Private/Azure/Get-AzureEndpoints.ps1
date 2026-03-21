function Get-AzureEndpoints {
    <#
    .SYNOPSIS
        Resolves Azure endpoints based on the current cloud environment.
    .DESCRIPTION
        Automatically detects the Azure environment (Commercial, Government, China, etc.)
        from the current Az context and returns the appropriate API endpoints.
        Supports sovereign clouds and air-gapped environments.
        Can be overridden with explicit environment name.
    .PARAMETER AzEnvironment
        Environment object for testing (mock).
    .PARAMETER EnvironmentName
        Explicit environment name override (AzureCloud, AzureUSGovernment, etc.).
    .OUTPUTS
        Hashtable with ResourceManagerUrl, PricingApiUrl, and EnvironmentName.
    .EXAMPLE
        $endpoints = Get-AzureEndpoints
        $endpoints.PricingApiUrl  # Returns https://prices.azure.com for Commercial
    .EXAMPLE
        $endpoints = Get-AzureEndpoints -EnvironmentName 'AzureUSGovernment'
        $endpoints.PricingApiUrl  # Returns https://prices.azure.us
    #>
    param(
        [Parameter(Mandatory = $false)]
        [object]$AzEnvironment,  # For testing - pass a mock environment object

        [Parameter(Mandatory = $false)]
        [string]$EnvironmentName  # Explicit override by name
    )

    # If explicit environment name provided, look it up
    if ($EnvironmentName) {
        try {
            $AzEnvironment = Get-AzEnvironment -Name $EnvironmentName -ErrorAction Stop
            if (-not $AzEnvironment) {
                Write-Warning "Environment '$EnvironmentName' not found. Using default Commercial cloud."
            }
            else {
                Write-Verbose "Using explicit environment: $EnvironmentName"
            }
        }
        catch {
            Write-Warning "Could not get environment '$EnvironmentName': $_. Using default Commercial cloud."
            $AzEnvironment = $null
        }
    }

    # Get the current Azure environment if not provided
    if (-not $AzEnvironment) {
        try {
            $context = Get-AzContext -ErrorAction Stop
            if (-not $context) {
                Write-Warning "No Azure context found. Using default Commercial cloud endpoints."
                $AzEnvironment = $null
            }
            else {
                $AzEnvironment = $context.Environment
            }
        }
        catch {
            Write-Warning "Could not get Azure context: $_. Using default Commercial cloud endpoints."
            $AzEnvironment = $null
        }
    }

    # Default to Commercial cloud if no environment detected
    if (-not $AzEnvironment) {
        return @{
            EnvironmentName    = 'AzureCloud'
            ResourceManagerUrl = 'https://management.azure.com'
            PricingApiUrl      = 'https://prices.azure.com/api/retail/prices'
        }
    }

    # Get the Resource Manager URL directly from the environment
    $armUrl = $AzEnvironment.ResourceManagerUrl
    if (-not $armUrl) {
        $armUrl = 'https://management.azure.com'
    }
    # Ensure no trailing slash
    $armUrl = $armUrl.TrimEnd('/')

    # Derive pricing API URL from the portal URL
    # Commercial: portal.azure.com -> prices.azure.com
    # Government: portal.azure.us -> prices.azure.us
    # China: portal.azure.cn -> prices.azure.cn
    $portalUrl = $AzEnvironment.ManagementPortalUrl
    if ($portalUrl) {
        # Replace only the 'portal' subdomain with 'prices' (more precise than global replace)
        $pricingUrl = $portalUrl -replace '^(https?://)?portal\.', '${1}prices.'
        $pricingUrl = $pricingUrl.TrimEnd('/')
        $pricingApiUrl = "$pricingUrl/api/retail/prices"
    }
    else {
        # Fallback based on known environment names
        $pricingApiUrl = switch ($AzEnvironment.Name) {
            'AzureUSGovernment' { 'https://prices.azure.us/api/retail/prices' }
            'AzureChinaCloud' { 'https://prices.azure.cn/api/retail/prices' }
            'AzureGermanCloud' { 'https://prices.microsoftazure.de/api/retail/prices' }
            default { 'https://prices.azure.com/api/retail/prices' }
        }
    }

    $endpoints = @{
        EnvironmentName    = $AzEnvironment.Name
        ResourceManagerUrl = $armUrl
        PricingApiUrl      = $pricingApiUrl
    }

    Write-Verbose "Azure Environment: $($endpoints.EnvironmentName)"
    Write-Verbose "Resource Manager URL: $($endpoints.ResourceManagerUrl)"
    Write-Verbose "Pricing API URL: $($endpoints.PricingApiUrl)"

    return $endpoints
}
