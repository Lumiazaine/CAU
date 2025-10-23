#Requires -Version 5.1
#Requires -Modules Pester

<#
.SYNOPSIS
    CI/CD Test Runner for AD_ADMIN Project with Quality Gates
.DESCRIPTION
    Comprehensive test execution pipeline with quality gates, coverage analysis, 
    and automated reporting for the AD_ADMIN system
.PARAMETER TestSuite
    Test suite to run (Unit, Integration, E2E, Performance, All)
.PARAMETER GenerateReports
    Generate detailed HTML and XML reports
.PARAMETER EnforceQualityGates
    Enforce quality gates and fail if not met
.PARAMETER CoverageThreshold
    Minimum code coverage percentage required (default: 95)
.PARAMETER MaxExecutionTime
    Maximum execution time in seconds (default: 300)
.PARAMETER ParallelExecution
    Enable parallel test execution
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("Unit", "Integration", "E2E", "Performance", "Security", "Regression", "All")]
    [string]$TestSuite = "All",
    
    [Parameter(Mandatory=$false)]
    [switch]$GenerateReports = $true,
    
    [Parameter(Mandatory=$false)]
    [switch]$EnforceQualityGates = $true,
    
    [Parameter(Mandatory=$false)]
    [ValidateRange(0, 100)]
    [int]$CoverageThreshold = 95,
    
    [Parameter(Mandatory=$false)]
    [int]$MaxExecutionTime = 300,
    
    [Parameter(Mandatory=$false)]
    [switch]$ParallelExecution = $true,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipSyntheticDataGeneration = $false
)

$ErrorActionPreference = "Stop"

# Test execution configuration
$Global:TestConfig = @{
    RootPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
    Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    MaxDegreeOfParallelism = 4
    QualityGates = @{
        MinCodeCoverage = $CoverageThreshold
        MaxFailedTests = 0
        MaxWarnings = 10
        CriticalBugTolerance = 0
        MaxExecutionTimeSeconds = $MaxExecutionTime
        MaxMemoryUsageMB = 512
    }
}

$Global:TestResults = @{
    StartTime = Get-Date
    EndTime = $null
    ExecutionTime = $null
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    SkippedTests = 0
    CodeCoverage = 0
    QualityGatesPassed = $false
    DetailedResults = @()
    Warnings = @()
    Errors = @()
}

function Write-TestLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "CRITICAL")]
        [string]$Level = "INFO"
    )
    
    $Color = switch ($Level) {
        "INFO" { "White" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        "CRITICAL" { "Magenta" }
    }
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    
    Write-Host $LogMessage -ForegroundColor $Color
    
    # Log to file
    $LogFile = Join-Path $Global:TestConfig.RootPath "Reports\test_execution_$($Global:TestConfig.Timestamp).log"
    Add-Content -Path $LogFile -Value $LogMessage -ErrorAction SilentlyContinue
}

function Initialize-TestEnvironment {
    Write-TestLog "Initializing test environment..." "INFO"
    
    try {
        # Create required directories
        $RequiredDirs = @("Reports", "Coverage", "Artifacts")
        foreach ($Dir in $RequiredDirs) {
            $DirPath = Join-Path $Global:TestConfig.RootPath $Dir
            if (-not (Test-Path $DirPath)) {
                New-Item -ItemType Directory -Path $DirPath -Force | Out-Null
            }
        }
        
        # Load Pester configuration
        $PesterConfigPath = Join-Path $Global:TestConfig.RootPath "pester.config.ps1"
        if (Test-Path $PesterConfigPath) {
            $Global:PesterConfiguration = & $PesterConfigPath
        } else {
            throw "Pester configuration not found at $PesterConfigPath"
        }
        
        # Generate synthetic test data if needed
        if (-not $SkipSyntheticDataGeneration) {
            $DataGenerator = Join-Path $Global:TestConfig.RootPath "TestData\Generate-SyntheticCSV.ps1"
            if (Test-Path $DataGenerator) {
                Write-TestLog "Generating synthetic test data..." "INFO"
                & $DataGenerator -GenerateAll | Out-Null
            }
        }
        
        # Initialize performance monitoring
        $Global:PerformanceCounters = @{
            MemoryAtStart = [System.GC]::GetTotalMemory($true)
            ProcessorTime = Get-Process -Id $PID | Select-Object -ExpandProperty TotalProcessorTime
        }
        
        Write-TestLog "Test environment initialized successfully" "SUCCESS"
        return $true
        
    } catch {
        Write-TestLog "Failed to initialize test environment: $($_.Exception.Message)" "CRITICAL"
        return $false
    }
}

function Get-TestSuites {
    param([string]$Suite)
    
    $AllSuites = @{
        "Unit" = @{
            Path = "Unit"
            Description = "Unit tests for individual components"
            Tags = @("Unit", "Fast")
            TimeoutMinutes = 10
        }
        "Integration" = @{
            Path = "Integration" 
            Description = "Integration tests with AD sandbox"
            Tags = @("Integration", "Slow")
            TimeoutMinutes = 20
        }
        "E2E" = @{
            Path = "E2E"
            Description = "End-to-end workflow tests"
            Tags = @("E2E", "Slow")
            TimeoutMinutes = 30
        }
        "Performance" = @{
            Path = "Performance"
            Description = "Performance and load tests"
            Tags = @("Performance", "Slow")
            TimeoutMinutes = 15
        }
        "Security" = @{
            Path = "Security"
            Description = "Security validation tests"
            Tags = @("Security", "Fast")
            TimeoutMinutes = 10
        }
        "Regression" = @{
            Path = "Regression"
            Description = "Regression tests for known issues"
            Tags = @("Regression", "Fast")
            TimeoutMinutes = 15
        }
    }
    
    if ($Suite -eq "All") {
        return $AllSuites
    } else {
        return @{ $Suite = $AllSuites[$Suite] }
    }
}

function Invoke-TestSuite {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$SuiteConfig,
        [Parameter(Mandatory=$true)]
        [string]$SuiteName
    )
    
    Write-TestLog "Executing test suite: $SuiteName - $($SuiteConfig.Description)" "INFO"
    
    $SuitePath = Join-Path $Global:TestConfig.RootPath $SuiteConfig.Path
    
    if (-not (Test-Path $SuitePath)) {
        Write-TestLog "Test suite path not found: $SuitePath" "WARNING"
        return @{
            Success = $false
            TestsRun = 0
            TestsPassed = 0
            TestsFailed = 0
            TestsSkipped = 0
            Duration = [TimeSpan]::Zero
            Message = "Test suite path not found"
        }
    }
    
    try {
        # Configure Pester for this suite
        $Configuration = [PesterConfiguration]::Default
        $Configuration.Run.Path = $SuitePath
        $Configuration.Run.PassThru = $true
        $Configuration.Run.Timeout = [TimeSpan]::FromMinutes($SuiteConfig.TimeoutMinutes)
        
        # Configure output
        $Configuration.Output.Verbosity = "Detailed"
        
        # Configure test result output
        $TestResultPath = Join-Path $Global:TestConfig.RootPath "Reports\$SuiteName-Results-$($Global:TestConfig.Timestamp).xml"
        $Configuration.TestResult.Enabled = $true
        $Configuration.TestResult.OutputPath = $TestResultPath
        $Configuration.TestResult.OutputFormat = "NUnitXml"
        
        # Configure code coverage for Unit and Integration tests
        if ($SuiteName -in @("Unit", "Integration")) {
            $Configuration.CodeCoverage.Enabled = $true
            $Configuration.CodeCoverage.Path = @(
                (Join-Path $Global:TestConfig.ProjectRoot "Modules\*.psm1"),
                (Join-Path $Global:TestConfig.ProjectRoot "*.ps1")
            )
            $CoverageOutputPath = Join-Path $Global:TestConfig.RootPath "Coverage\$SuiteName-Coverage-$($Global:TestConfig.Timestamp).xml"
            $Configuration.CodeCoverage.OutputPath = $CoverageOutputPath
            $Configuration.CodeCoverage.OutputFormat = "JaCoCo"
        }
        
        # Execute tests
        $StartTime = Get-Date
        $Result = Invoke-Pester -Configuration $Configuration
        $EndTime = Get-Date
        $Duration = $EndTime - $StartTime
        
        # Analyze results
        $TestsRun = $Result.TotalCount
        $TestsPassed = $Result.PassedCount
        $TestsFailed = $Result.FailedCount
        $TestsSkipped = $Result.SkippedCount
        
        $Success = ($TestsFailed -eq 0) -and ($TestsRun -gt 0)
        
        Write-TestLog "Suite '$SuiteName' completed: $TestsRun tests, $TestsPassed passed, $TestsFailed failed, $TestsSkipped skipped" $(if ($Success) { "SUCCESS" } else { "ERROR" })
        
        # Store detailed results
        $Global:TestResults.DetailedResults += @{
            SuiteName = $SuiteName
            Success = $Success
            TestsRun = $TestsRun
            TestsPassed = $TestsPassed
            TestsFailed = $TestsFailed
            TestsSkipped = $TestsSkipped
            Duration = $Duration
            CodeCoverage = if ($Result.CodeCoverage) { $Result.CodeCoverage.CoveragePercent } else { 0 }
            FailedTests = $Result.Failed
        }
        
        return @{
            Success = $Success
            TestsRun = $TestsRun
            TestsPassed = $TestsPassed
            TestsFailed = $TestsFailed  
            TestsSkipped = $TestsSkipped
            Duration = $Duration
            CodeCoverage = if ($Result.CodeCoverage) { $Result.CodeCoverage.CoveragePercent } else { 0 }
            Result = $Result
        }
        
    } catch {
        Write-TestLog "Error executing test suite '$SuiteName': $($_.Exception.Message)" "ERROR"
        
        return @{
            Success = $false
            TestsRun = 0
            TestsPassed = 0
            TestsFailed = 1
            TestsSkipped = 0
            Duration = [TimeSpan]::Zero
            Error = $_.Exception.Message
        }
    }
}

function Test-QualityGates {
    Write-TestLog "Evaluating quality gates..." "INFO"
    
    $QualityGateResults = @{
        Passed = $true
        Violations = @()
        Metrics = @{}
    }
    
    # Calculate overall metrics
    $TotalTests = ($Global:TestResults.DetailedResults | Measure-Object -Property TestsRun -Sum).Sum
    $TotalPassed = ($Global:TestResults.DetailedResults | Measure-Object -Property TestsPassed -Sum).Sum
    $TotalFailed = ($Global:TestResults.DetailedResults | Measure-Object -Property TestsFailed -Sum).Sum
    $TotalSkipped = ($Global:TestResults.DetailedResults | Measure-Object -Property TestsSkipped -Sum).Sum
    
    $OverallCoverage = if ($Global:TestResults.DetailedResults.Count -gt 0) {
        ($Global:TestResults.DetailedResults | Where-Object { $_.CodeCoverage -gt 0 } | Measure-Object -Property CodeCoverage -Average).Average
    } else { 0 }
    
    $ExecutionTime = ((Get-Date) - $Global:TestResults.StartTime).TotalSeconds
    
    # Update global results
    $Global:TestResults.TotalTests = $TotalTests
    $Global:TestResults.PassedTests = $TotalPassed
    $Global:TestResults.FailedTests = $TotalFailed
    $Global:TestResults.SkippedTests = $TotalSkipped
    $Global:TestResults.CodeCoverage = [Math]::Round($OverallCoverage, 2)
    $Global:TestResults.ExecutionTime = [TimeSpan]::FromSeconds($ExecutionTime)
    
    $QualityGateResults.Metrics = @{
        TotalTests = $TotalTests
        PassedTests = $TotalPassed
        FailedTests = $TotalFailed
        CodeCoverage = $OverallCoverage
        ExecutionTimeSeconds = $ExecutionTime
    }
    
    # Test Quality Gate 1: Code Coverage
    if ($OverallCoverage -lt $Global:TestConfig.QualityGates.MinCodeCoverage) {
        $QualityGateResults.Passed = $false
        $QualityGateResults.Violations += "Code coverage is $([Math]::Round($OverallCoverage, 2))%, minimum required is $($Global:TestConfig.QualityGates.MinCodeCoverage)%"
    }
    
    # Test Quality Gate 2: Failed Tests
    if ($TotalFailed -gt $Global:TestConfig.QualityGates.MaxFailedTests) {
        $QualityGateResults.Passed = $false
        $QualityGateResults.Violations += "Failed tests count is $TotalFailed, maximum allowed is $($Global:TestConfig.QualityGates.MaxFailedTests)"
    }
    
    # Test Quality Gate 3: Execution Time
    if ($ExecutionTime -gt $Global:TestConfig.QualityGates.MaxExecutionTimeSeconds) {
        $QualityGateResults.Passed = $false
        $QualityGateResults.Violations += "Execution time is $([Math]::Round($ExecutionTime, 2))s, maximum allowed is $($Global:TestConfig.QualityGates.MaxExecutionTimeSeconds)s"
    }
    
    # Test Quality Gate 4: Memory Usage
    $CurrentMemory = [System.GC]::GetTotalMemory($false)
    $MemoryUsageMB = ($CurrentMemory - $Global:PerformanceCounters.MemoryAtStart) / 1MB
    if ($MemoryUsageMB -gt $Global:TestConfig.QualityGates.MaxMemoryUsageMB) {
        $QualityGateResults.Passed = $false
        $QualityGateResults.Violations += "Memory usage is $([Math]::Round($MemoryUsageMB, 2))MB, maximum allowed is $($Global:TestConfig.QualityGates.MaxMemoryUsageMB)MB"
    }
    
    # Test Quality Gate 5: Critical Issues (from test failures)
    $CriticalIssues = 0
    foreach ($DetailedResult in $Global:TestResults.DetailedResults) {
        if ($DetailedResult.FailedTests) {
            $CriticalIssues += ($DetailedResult.FailedTests | Where-Object { $_.Tag -contains "Critical" }).Count
        }
    }
    
    if ($CriticalIssues -gt $Global:TestConfig.QualityGates.CriticalBugTolerance) {
        $QualityGateResults.Passed = $false
        $QualityGateResults.Violations += "Critical issues count is $CriticalIssues, maximum allowed is $($Global:TestConfig.QualityGates.CriticalBugTolerance)"
    }
    
    # Log quality gate results
    if ($QualityGateResults.Passed) {
        Write-TestLog "All quality gates PASSED ✓" "SUCCESS"
    } else {
        Write-TestLog "Quality gates FAILED ✗" "ERROR"
        foreach ($Violation in $QualityGateResults.Violations) {
            Write-TestLog "  - $Violation" "ERROR"
        }
    }
    
    $Global:TestResults.QualityGatesPassed = $QualityGateResults.Passed
    
    return $QualityGateResults
}

function New-TestReport {
    Write-TestLog "Generating test reports..." "INFO"
    
    try {
        $ReportPath = Join-Path $Global:TestConfig.RootPath "Reports\TestReport-$($Global:TestConfig.Timestamp).html"
        
        $HtmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>AD_ADMIN Test Execution Report</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f8ff; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .metric { display: inline-block; margin: 10px; padding: 15px; border-radius: 5px; min-width: 150px; text-align: center; }
        .success { background-color: #d4edda; color: #155724; }
        .warning { background-color: #fff3cd; color: #856404; }
        .error { background-color: #f8d7da; color: #721c24; }
        .info { background-color: #d1ecf1; color: #0c5460; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background-color: #f2f2f2; font-weight: bold; }
        .quality-gates { margin: 20px 0; }
        .violation { color: #721c24; font-weight: bold; }
        .pass { color: #155724; font-weight: bold; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🧪 AD_ADMIN Test Execution Report</h1>
        <p><strong>Execution Date:</strong> $($Global:TestResults.StartTime.ToString("yyyy-MM-dd HH:mm:ss"))</p>
        <p><strong>Duration:</strong> $($Global:TestResults.ExecutionTime)</p>
        <p><strong>Test Suite:</strong> $TestSuite</p>
    </div>
    
    <div class="metrics">
        <div class="metric $(if ($Global:TestResults.FailedTests -eq 0) { 'success' } else { 'error' })">
            <h3>$($Global:TestResults.TotalTests)</h3>
            <p>Total Tests</p>
        </div>
        <div class="metric success">
            <h3>$($Global:TestResults.PassedTests)</h3>
            <p>Passed Tests</p>
        </div>
        <div class="metric $(if ($Global:TestResults.FailedTests -eq 0) { 'success' } else { 'error' })">
            <h3>$($Global:TestResults.FailedTests)</h3>
            <p>Failed Tests</p>
        </div>
        <div class="metric $(if ($Global:TestResults.CodeCoverage -ge $CoverageThreshold) { 'success' } else { 'error' })">
            <h3>$($Global:TestResults.CodeCoverage)%</h3>
            <p>Code Coverage</p>
        </div>
    </div>
    
    <div class="quality-gates">
        <h2>🎯 Quality Gates</h2>
        <p class="$(if ($Global:TestResults.QualityGatesPassed) { 'pass' } else { 'violation' })">
            Status: $(if ($Global:TestResults.QualityGatesPassed) { 'PASSED ✓' } else { 'FAILED ✗' })
        </p>
    </div>
    
    <h2>📊 Detailed Results by Test Suite</h2>
    <table>
        <tr>
            <th>Test Suite</th>
            <th>Tests Run</th>
            <th>Passed</th>
            <th>Failed</th>
            <th>Skipped</th>
            <th>Duration</th>
            <th>Coverage %</th>
            <th>Status</th>
        </tr>
"@

        foreach ($Result in $Global:TestResults.DetailedResults) {
            $StatusClass = if ($Result.Success) { "success" } else { "error" }
            $StatusText = if ($Result.Success) { "✓ PASS" } else { "✗ FAIL" }
            
            $HtmlReport += @"
        <tr>
            <td>$($Result.SuiteName)</td>
            <td>$($Result.TestsRun)</td>
            <td>$($Result.TestsPassed)</td>
            <td>$($Result.TestsFailed)</td>
            <td>$($Result.TestsSkipped)</td>
            <td>$($Result.Duration.ToString("mm\:ss"))</td>
            <td>$([Math]::Round($Result.CodeCoverage, 2))</td>
            <td class="$StatusClass">$StatusText</td>
        </tr>
"@
        }
        
        $HtmlReport += @"
    </table>
    
    <h2>🔍 Test Environment Information</h2>
    <ul>
        <li><strong>PowerShell Version:</strong> $($PSVersionTable.PSVersion)</li>
        <li><strong>OS Version:</strong> $($PSVersionTable.OS)</li>
        <li><strong>Pester Version:</strong> $((Get-Module -Name Pester).Version)</li>
        <li><strong>Test Framework:</strong> Comprehensive AD_ADMIN QA Framework v1.0</li>
        <li><strong>Quality Gates Enforced:</strong> $(if ($EnforceQualityGates) { 'Yes' } else { 'No' })</li>
    </ul>
    
    <footer style="margin-top: 40px; padding-top: 20px; border-top: 1px solid #ddd; font-size: 0.9em; color: #666;">
        Generated by AD_ADMIN Test Framework | $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    </footer>
</body>
</html>
"@
        
        Set-Content -Path $ReportPath -Value $HtmlReport -Encoding UTF8
        Write-TestLog "HTML report generated: $ReportPath" "SUCCESS"
        
        # Generate JSON report for CI/CD integration
        $JsonReportPath = Join-Path $Global:TestConfig.RootPath "Reports\TestResults-$($Global:TestConfig.Timestamp).json"
        $JsonReport = $Global:TestResults | ConvertTo-Json -Depth 4
        Set-Content -Path $JsonReportPath -Value $JsonReport -Encoding UTF8
        Write-TestLog "JSON report generated: $JsonReportPath" "SUCCESS"
        
        return $true
        
    } catch {
        Write-TestLog "Failed to generate test report: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Show-ExecutionSummary {
    $Global:TestResults.EndTime = Get-Date
    
    Write-Host "`n" -NoNewline
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "                    🧪 TEST EXECUTION SUMMARY                    " -ForegroundColor Cyan  
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    
    Write-Host "📊 Results:" -ForegroundColor White
    Write-Host "   Total Tests: " -NoNewline -ForegroundColor White
    Write-Host $Global:TestResults.TotalTests -ForegroundColor Cyan
    Write-Host "   Passed: " -NoNewline -ForegroundColor White  
    Write-Host $Global:TestResults.PassedTests -ForegroundColor Green
    Write-Host "   Failed: " -NoNewline -ForegroundColor White
    Write-Host $Global:TestResults.FailedTests -ForegroundColor $(if ($Global:TestResults.FailedTests -eq 0) { "Green" } else { "Red" })
    Write-Host "   Skipped: " -NoNewline -ForegroundColor White
    Write-Host $Global:TestResults.SkippedTests -ForegroundColor Yellow
    
    Write-Host "`n📈 Quality Metrics:" -ForegroundColor White
    Write-Host "   Code Coverage: " -NoNewline -ForegroundColor White
    Write-Host "$($Global:TestResults.CodeCoverage)%" -ForegroundColor $(if ($Global:TestResults.CodeCoverage -ge $CoverageThreshold) { "Green" } else { "Red" })
    Write-Host "   Execution Time: " -NoNewline -ForegroundColor White
    Write-Host $Global:TestResults.ExecutionTime -ForegroundColor Cyan
    
    Write-Host "`n🎯 Quality Gates: " -NoNewline -ForegroundColor White
    if ($Global:TestResults.QualityGatesPassed) {
        Write-Host "PASSED ✓" -ForegroundColor Green
    } else {
        Write-Host "FAILED ✗" -ForegroundColor Red
    }
    
    if ($GenerateReports) {
        Write-Host "`n📄 Reports generated in: " -NoNewline -ForegroundColor White
        Write-Host (Join-Path $Global:TestConfig.RootPath "Reports") -ForegroundColor Cyan
    }
    
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
}

# Main execution flow
function Main {
    Write-TestLog "Starting AD_ADMIN Test Execution Pipeline" "INFO"
    Write-TestLog "Test Suite: $TestSuite | Quality Gates: $EnforceQualityGates | Coverage Threshold: $CoverageThreshold%" "INFO"
    
    # Initialize test environment
    if (-not (Initialize-TestEnvironment)) {
        Write-TestLog "Failed to initialize test environment - aborting" "CRITICAL"
        exit 1
    }
    
    # Get test suites to execute
    $TestSuites = Get-TestSuites -Suite $TestSuite
    
    # Execute test suites
    foreach ($SuiteName in $TestSuites.Keys) {
        $SuiteConfig = $TestSuites[$SuiteName]
        $Result = Invoke-TestSuite -SuiteConfig $SuiteConfig -SuiteName $SuiteName
        
        if (-not $Result.Success) {
            Write-TestLog "Test suite '$SuiteName' failed" "ERROR"
        }
    }
    
    # Evaluate quality gates
    $QualityGateResults = Test-QualityGates
    
    # Generate reports if requested
    if ($GenerateReports) {
        New-TestReport | Out-Null
    }
    
    # Show execution summary
    Show-ExecutionSummary
    
    # Determine exit code
    $ExitCode = 0
    
    if ($EnforceQualityGates -and -not $Global:TestResults.QualityGatesPassed) {
        Write-TestLog "Quality gates failed - build should be marked as failed" "CRITICAL"
        $ExitCode = 1
    } elseif ($Global:TestResults.FailedTests -gt 0) {
        Write-TestLog "Some tests failed - build marked as unstable" "ERROR"
        $ExitCode = 1
    } else {
        Write-TestLog "All tests passed successfully! 🎉" "SUCCESS"
        $ExitCode = 0
    }
    
    Write-TestLog "Test execution completed with exit code: $ExitCode" "INFO"
    exit $ExitCode
}

# Execute main function
Main