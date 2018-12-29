<#	
	.NOTES
	===========================================================================
	 Created on:   	28.12.2018
	 Revision date: 
	 Created by:   	Daniele Catanesi
	 Organization: 	https://PsCustomObject.github.io
	 Filename:     	Remove-OldFiles.ps1
	 Version:		1.0.0 - Initial Script Release
	===========================================================================
	
	.SYNOPSIS
		Scripts takes a directory as input and delete file older than defined
		number of days

	.DESCRIPTION
		Script gathers all files in the specified folder, compares files'
		creation date and if older than the value defined in the $timeSpan variable
		will log a message and delete the file

		Script configuration is centrally read from a customizable CSV file which 
		contains: 
			- Path
			- Tolerance in Days

#>

#region Support Function
function New-LogEntry
{
<#
	.SYNOPSIS
		Function to create a log file for PowerShell scripts
	
	.DESCRIPTION
		Function supports both writing to a text file (default), sending messages only to console via ConsoleOnly parameter or both via WriteToConsole parameter.
		
		The BufferOnly parameter will not write message neither to console or logfile but save to a temporary buffer which can then be piped to file or printed to screen.
	
	.PARAMETER logMessage
		A string containing the message PowerShell should log for example about current action being performed.
	
	.PARAMETER WriteToConsole
		Writes the log message both to the log file and the interactive
		console, similar to built-in Write-Host.
	
	.PARAMETER LogName
		Specifies the path and log file name that will be created.
		
		Parameter only accepts full path IE C:\MyLog.log
	
	.PARAMETER isErrorMessage
		Prepend the log message with the [Error] tag in file and
		uses the Write-Error built-in cmdlet to throw a non terminating
		error in PowerShell Console
	
	.PARAMETER IsWarningMessage
		Prepend the log message with the [Warning] tag in file and
		uses the Write-Warning built-in cmdlet to throw a warning in
		PowerShell Console
	
	.PARAMETER ConsoleOnly
		Print the log message to console without writing it file
	
	.PARAMETER BufferOnly
		Saves log message to a variable without printing to console
		or writing to log file
	
	.PARAMETER SaveToBuffer
		Saves log message to a variable for later use
	
	.PARAMETER NoTimeStamp
		Suppresses timestamp in log message
	
	.EXAMPLE
		Example 1: Write a log message to log file
		PS C:\> New-LogEntry -LogMessage "Test Entry"
		
		This will simply output the message "Test Entry" in the logfile
		
		Example 2: Write a log message to console only
		PS C:\> New-LogEntry -LogMessage "Test Entry" -ConsoleOnly
		
		This will print Test Entry on console
		
		Example 3: Write an error log message
		New-LogEntry -LogMessage "Test Log Error" -isErrorMessage
		
		This will prepend the [Error] tag in front of
		log message like:
		
		[06-21 03:20:57] : [Error] - Test Log Error
	
	.NOTES
		Additional information about the function.
#>
	
	[CmdletBinding(ConfirmImpact = 'High',
				   PositionalBinding = $true,
				   SupportsShouldProcess = $true)]
	param
	(
		[Parameter(Mandatory = $true,
				   ValueFromPipeline = $true)]
		[AllowNull()]
		[Alias('Log', 'Message')]
		[string]
		$LogMessage,
		[Alias('Print', 'Echo', 'Console')]
		[switch]
		$WriteToConsole = $false,
		[AllowNull()]
		[Alias('Path', 'LogFile', 'File', 'LogPath')]
		[string]
		$LogName,
		[Alias('Error', 'IsError', 'WriteError')]
		[switch]
		$IsErrorMessage = $false,
		[Alias('Warning', 'IsWarning', 'WriteWarning')]
		[switch]
		$IsWarningMessage = $false,
		[Alias('EchoOnly')]
		[switch]
		$ConsoleOnly = $false,
		[switch]
		$BufferOnly = $false,
		[switch]
		$SaveToBuffer = $false,
		[Alias('Nodate', 'NoStamp')]
		[switch]
		$NoTimeStamp = $false
	)
	
	# Use script path if no filepath is specified
	if (([string]::IsNullOrEmpty($LogName) -eq $true) -and
		(!($ConsoleOnly)))
	{
		$LogName = $PSCommandPath + '-LogFile-' + $(Get-Date -Format 'yyyy-MM-dd') + '.log'
	}
	
	# Don't do anything on empty Log Message
	if ([string]::IsNullOrEmpty($logMessage) -eq $true)
	{
		return
	}
	
	# Format log message
	if (($isErrorMessage) -and
		(!($ConsoleOnly)))
	{
		if ($NoTimeStamp)
		{
			$tmpMessage = "[Error] - $logMessage"
		}
		else
		{
			$tmpMessage = "[$(Get-Date -Format 'MM-dd hh:mm:ss')] : [Error] - $logMessage"
		}
	}
	elseif (($IsWarningMessage -eq $true) -and
		(!($ConsoleOnly)))
	{
		if ($NoTimeStamp)
		{
			$tmpMessage = "[Warning] - $logMessage"
		}
		else
		{
			$tmpMessage = "[$(Get-Date -Format 'MM-dd hh:mm:ss')] : [Warning] - $logMessage"
		}
	}
	else
	{
		if (!($ConsoleOnly))
		{
			if ($NoTimeStamp)
			{
				$tmpMessage = $logMessage
			}
			else
			{
				$tmpMessage = "[$(Get-Date -Format 'MM-dd hh:mm:ss')] : $logMessage"
			}
		}
	}
	
	# Write log messages to console
	if (($ConsoleOnly) -or
		($WriteToConsole))
	{
		if ($IsErrorMessage)
		{
			Write-Error $logMessage
		}
		elseif ($IsWarningMessage)
		{
			Write-Warning $logMessage
		}
		else
		{
			Write-Output -InputObject $logMessage
		}
		
		# Write to console and exit
		if ($ConsoleOnly -eq $true)
		{
			return
		}
	}
	
	# Write log messages to file
	if (([string]::IsNullOrEmpty($LogName) -eq $false) -and
		($BufferOnly -ne $true))
	{
		$paramOutFile = @{
			InputObject = $tmpMessage
			FilePath    = $LogName
			Append	    = $true
			Encoding    = 'utf8'
		}
		
		Out-File @paramOutFile
	}
	
	# Save message to buffer
	if (($BufferOnly -eq $true) -or
		($SaveToBuffer -eq $true))
	{
		$script:messageBuffer += $tmpMessage + '`r`n'
		
		# Remove blank lines
		$script:messageBuffer = $script:messageBuffer -creplace '(?m)^\s*\r?\n', ''
	}
}
#endregion Support Function

# Setup environment
[datetime]$currentDate = Get-Date
[string]$dateString = $currentDate.ToString('yyyyMMdd')
[string]$logPath = '\\MyServer\ScriptLog\Remove-OldFiles\'
[string]$logTimeStamp = $currentDate.ToString('hh:mm:ss')

# Define the log path location
[string]$LogName = $logPath + $dateString + '-RemoveOldFiles.log'

# Define Ignore control file
[string]$ignoreFile = 'ignore'

# Start a counter
[int]$deletedFiles = 0

# Get all the files in the defined path(s)
[array]$cleanupPath = Import-Csv '\\MyServer\CleanupConfig$\FilePaths.csv' -Delimiter ','

# Store exception files
[array]$filesException = @()

New-LogEntry -LogMessage '-----------------------------------------------------------------' -LogName $LogName
New-LogEntry -LogMessage "	Remove-OldFiles - Execution Started at $logTimeStamp" -LogName $LogName
New-LogEntry -LogMessage '-----------------------------------------------------------------' -LogName $LogName

foreach ($path in $cleanupPath)
{
	# Check we have something
	if ([string]::IsNullOrEmpty($path.'CleanupPath') -eq $true)
	{
		New-LogEntry -LogMessage 'Cleanup path is empty! - No action will be taken' -LogName $LogName
		
		# Exit immediately
		return
	}
	
	if (Get-ChildItem -Path $path.'CleanupPath' -File $ignoreFile)
	{
		New-LogEntry -LogMessage "Ignore file $ignoreFile found in $($path.'CleanupPath') - Skipping files in directory!" -LogName $LogName
		
		# Break loop
		continue
	}
	
	New-LogEntry -LogMessage "Starting to process files in $($path.'CleanupPath')" -LogName $LogName
	
	#region Csv format check
	# Check if we have a tolerance defined or use default
	if ([string]::IsNullOrEmpty($path.'AgeTolerance') -eq $true)
	{
		[int]$fileAgeTolerance = 90	
	}
	else
	{
		[int]$fileAgeTolerance = $path.'AgeTolerance'
	}
	
	# Check if user specified extension filter
	if ([string]::IsNullOrEmpty($path.'FileExtension') -eq $true)
	{
		[string]$fileFilter = '*.*'
	}
	else
	{
		[string]$fileFilter = '*.' + $path.'FileExtension'
	}

	# Check if user specified recursion
	if ([string]::IsNullOrEmpty($path.'IncludeSubFolders') -eq $true)
	{
		[int]$recursiveSearch = 0
	}
	else
	{
		[int]$recursiveSearch = 1
	}
	#endregion Csv format check
	
	# Define path(s) to scan
	[string]$filePath = $path.'CleanupPath'
	
	# Check if path is still valid
	if (!(Test-Path -Path $filePath))
	{
		New-LogEntry -LogMessage "Path $filePath is not valid! - Processing aborted" -IsErrorMessage -LogName $LogName

		continue
	}

	# File age tolerance
	[datetime]$ageTimeSpan = (Get-Date).AddDays(-$fileAgeTolerance)
	
	New-LogEntry -LogMessage "Cleanup Script parameters:
					Recursive Search: $recursiveSearch (0 means no recursion, 1 recurse in subfolders)
					File Age Tolerance: $fileAgeTolerance
					File Type Filter: $fileFilter" -LogName $LogName
	
	# Check if search is recursive
	switch ($recursiveSearch)
	{
		0 # No recursion
		{
			try
			{
				$filesToPurge = Get-ChildItem -Path $filePath -Filter $fileFilter -File |
				Where-Object { $_.LastWriteTime -lt $ageTimeSpan }
				
				if ($filesToPurge.Count -gt 0)
				{
					foreach ($file in $filesToPurge)
					{
						# Get file full path
						[string]$fileName = $file.FullName
						
						New-LogEntry -LogMessage "Processing file $fileName" -LogName $LogName
						
						# Calculate file age - Used for logging purposes
						[timespan]$fileAge = ((Get-Date) - $file.LastWriteTime)
						
						New-LogEntry -LogMessage "File $file was last written $($fileAge.Days) days ago which is greater than $fileAgeTolerance day(s) - Deleting file" -LogName $LogName
						
						try
						{
							# Remove file
							Remove-Item $fileName -Confirm:$false
							
							# Increment counter
							$deletedFiles++
						}
						catch
						{
							New-LogEntry -LogMessage "File $fileName cannot be removed - Please check permissions on file/folder" -LogName $LogName
							New-LogEntry -LogMessage "Reported exception is $Error[0]" -LogName $LogName
							
							# Add file/path to exception variable
							$filesException +=$fileName
						}
					}
				}
			}
			catch
			{
				New-LogEntry -LogMessage "Issues accessing $filePath - Please check folder permissions" -LogName $LogName
				New-LogEntry -LogMessage "Reported exception is $Error[0]" -LogName $LogName
			}
			break
		}
		
		1 # Recurse in subfolders
		{
			try
			{
				$filesToPurge = Get-ChildItem -Path $filePath -Filter $fileFilter -File -Recurse |
				Where-Object { $_.LastWriteTime -lt $ageTimeSpan }
				
				if ($filesToPurge.Count -gt 0)
				{
					# Check if any folder should be skipped
					if ($skipControl = Get-ChildItem -Path $filePath -File $ignoreFile -Recurse)
					{
						[array]$skippedFolders = $skipControl.'DirectoryName'
						
						New-LogEntry -LogMessage "Ignore file found in $skippedFolders folder(s)" -LogName $LogName
						New-LogEntry -LogMessage 'All child items in folder(s) will be ignored' -LogName $LogName
					}
					
					# Cycle through the filders 
					foreach ($file in $filesToPurge)
					{
						[string]$fileParentContainer = $file.'DirectoryName'
						
						# Get file full path
						[string]$fileName = $file.FullName
						
						#if ($fileParentContainer -notlike $skippedFolders)
						if ($skippedFolders -notcontains $fileParentContainer)
						{
							New-LogEntry -LogMessage "Processing file $fileName" -LogName $LogName
							
							# Calculate file age - Used for logging purposes
							[timespan]$fileAge = ((Get-Date) - $file.LastWriteTime)
							
							New-LogEntry -LogMessage "File $file was last written $($fileAge.Days) days ago which is greater than $fileAgeTolerance day(s) - Deleting file" -LogName $LogName
							
							try
							{
								# Remove file
								Remove-Item $fileName -Confirm:$false
								
								# Increment counter
								$deletedFiles++
							}
							catch
							{
								New-LogEntry -LogMessage "File $fileName cannot be removed - Please check permissions on file/folder" -LogName $LogName
								New-LogEntry -LogMessage "Reported exception is $Error[0]" -LogName $LogName
							}
						}
						else
						{
							New-LogEntry -LogMessage "File $fileName will be skipped - Ignore file found in containing folder" -LogName $LogName
						}
					}
				}
			}
			catch
			{
				New-LogEntry -LogMessage "Issues accessing $filePath - Please check folder permissions" -LogName $LogName
				New-LogEntry -LogMessage "Reported exception is $Error[0]" -LogName $LogName
			}
			break
		}

		default
		{
			New-LogEntry -LogMessage "IncludeSubFolders value in CSV $recursiveSearch unknown" -IsErrorMessage -LogName $LogName
			New-LogEntry -LogMessage 'Entry will not be processed - Review Configuration file' -IsErrorMessage -LogName $LogName
			
			# Unknown break loop
			continue
		}
	}
}

New-LogEntry "$deletedFiles item(s) have been removed from the log directory" -LogName $LogName

# Update timestamp
[datetime]$currentDate = Get-Date
[string]$logTimeStamp = $currentDate.ToString('hh:mm:ss')

New-LogEntry -LogMessage '-----------------------------------------------------------------' -LogFilePath $LogName
New-LogEntry -LogMessage "	Remove-OldFiles - Execution Completed at $logTimeStamp" -LogFilePath $LogName
New-LogEntry -LogMessage '-----------------------------------------------------------------' -LogFilePath $LogName