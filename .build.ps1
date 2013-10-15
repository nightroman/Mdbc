
<#
.Synopsis
	Build script (https://github.com/nightroman/Invoke-Build)

.Description
	How to use this script and build the module:

	Copy MongoDB.Bson.dll and MongoDB.Driver.dll from the released package to
	the Module directory. The project Mdbc.csproj assumes they are there.

	Get the utility script Invoke-Build.ps1:
	https://github.com/nightroman/Invoke-Build

	Copy it to the path. Set location to this directory. Build:
	PS> Invoke-Build Build

	This command builds the module and installs it to the $ModuleRoot which is
	the working location of the Mdbc module. The build fails if the module is
	currently in use. Ensure it is not and then repeat.

	The build task Help fails if the help builder Helps is not installed.
	Ignore this or better get and use the script (it is really easy):
	https://github.com/nightroman/Helps

	In order to deal with the latest C# driver sources set the environment
	variable MongoDBCSharpDriverRepo to its repository path. Then all tasks
	*Driver from this script should work as well.
#>

param
(
	$Configuration = 'Release'
)

# Standard location of the Mdbc module (caveat: may not work if MyDocuments is not standard)
$ModuleRoot = Join-Path ([Environment]::GetFolderPath('MyDocuments')) WindowsPowerShell\Modules\Mdbc

# Use MSBuild.
use Framework\v4.0.30319 MSBuild

# Build (incremental).
task Build {
	exec { MSBuild Src\Mdbc.csproj /t:Build /p:Configuration=$Configuration }
}

# Rebuild all (force).
task Rebuild {
	Invoke-Build Clean
	Remove-Item $ModuleRoot -Force -Recurse -ErrorAction 0
},
Build

# Clean all.
task Clean RemoveMarkdownHtml, {
	Remove-Item z, Src\bin, Src\obj, Module\Mdbc.dll, *.nupkg -Force -Recurse -ErrorAction 0
}

# Copy all to the module root directory and then build help.
# It is called as the post-build event of Mdbc.csproj.
task PostBuild {
	Copy-Item Src\Bin\$Configuration\Mdbc.dll Module
	exec { robocopy Module $ModuleRoot /s /np /r:0 /xf *-Help.ps1 } (0..3)
},
@{Help=1}

# Build module help by Helps (https://github.com/nightroman/Helps).
task Help -Inputs (Get-Item Src\Commands\*, Module\en-US\Mdbc.dll-Help.ps1) -Outputs "$ModuleRoot\en-US\Mdbc.dll-Help.xml" {
	. Helps.ps1
	Convert-Helps Module\en-US\Mdbc.dll-Help.ps1 $Outputs
}

# Test help examples.
task TestHelpExample {
	. Helps.ps1
	Test-Helps Module\en-US\Mdbc.dll-Help.ps1
}

# Test synopsis of each cmdlet and warn about unexpected.
task TestHelpSynopsis {
	Import-Module Mdbc
	Get-Command *-Mdbc* -CommandType cmdlet | Get-Help | .{process{
		if (!$_.Synopsis.EndsWith('.')) {
			Write-Warning "$($_.Name) : unexpected/missing synopsis"
		}
	}}
}

# Update help then run help tests.
task TestHelp Help, TestHelpExample, TestHelpSynopsis

# Copy external scripts from their working location to the project.
# It fails if the scripts are not available.
task UpdateScript -Partial `
-Inputs {Get-Command Mdbc.ps1, Update-MongoFiles.ps1, Get-MongoFile.ps1 | %{ $_.Definition }} `
-Outputs {process{ "Scripts\$(Split-Path -Leaf $_)" }} `
{process{ Copy-Item $_ $2 }}

# Pull C# driver sources.
task PullDriver {
	assert $env:MongoDBCSharpDriverRepo
	Set-Location $env:MongoDBCSharpDriverRepo
	exec { git pull }
}

# Build driver assemblies and copy to Module.
task BuildDriver {
	assert $env:MongoDBCSharpDriverRepo
	exec { MSBuild $env:MongoDBCSharpDriverRepo\CSharpDriver-2010.sln /t:Build /p:Configuration=Release }
	Copy-Item $env:MongoDBCSharpDriverRepo\Driver\bin\Release\*.dll Module
}

# Clean driver sources.
task CleanDriver {
	assert $env:MongoDBCSharpDriverRepo
	exec { MSBuild $env:MongoDBCSharpDriverRepo\CSharpDriver-2010.sln /t:Clean /p:Configuration=Release }
}

# Pull the latest driver, build it, then build Mdbc, test and clean all.
task Driver PullDriver, BuildDriver, Build, Test, Clean, CleanDriver

# Import markdown tasks ConvertMarkdown and RemoveMarkdownHtml.
# <https://github.com/nightroman/Invoke-Build/wiki/Partial-Incremental-Tasks>
try { Markdown.tasks.ps1 }
catch { task ConvertMarkdown; task RemoveMarkdownHtml }

# Make the package in z\tools for NuGet.
task Package ConvertMarkdown, @{UpdateScript=1}, {
	Remove-Item [z] -Force -Recurse
	$null = mkdir z\tools\Mdbc\en-US, z\tools\Mdbc\Scripts

	Copy-Item -Destination z\tools\Mdbc `
	LICENSE.txt,
	$ModuleRoot\Mdbc.dll,
	$ModuleRoot\Mdbc.Format.ps1xml,
	$ModuleRoot\Mdbc.psd1,
	$ModuleRoot\MongoDB.Bson.dll,
	$ModuleRoot\MongoDB.Driver.dll

	Copy-Item -Destination z\tools\Mdbc\en-US `
	$ModuleRoot\en-US\about_Mdbc.help.txt,
	$ModuleRoot\en-US\Mdbc.dll-Help.xml

	Copy-Item -Destination z\tools\Mdbc\Scripts `
	Scripts\Mdbc.ps1,
	Scripts\Get-MongoFile.ps1,
	Scripts\Update-MongoFiles.ps1

	Move-Item -Destination z\tools\Mdbc `
	README.htm,
	Release-Notes.htm
}

# Set $script:Version = assembly version
task Version {
	assert ((Get-Item $ModuleRoot\Mdbc.dll).VersionInfo.FileVersion -match '^(\d+\.\d+\.\d+)')
	$script:Version = $matches[1]
}

# Make NuGet package.
task NuGet Package, Version, {
	$text = @'
Mdbc is the Windows PowerShell module based on the official MongoDB C# driver.
It makes MongoDB scripting easy and represents yet another MongoDB shell.
'@
	# nuspec
	Set-Content z\Package.nuspec @"
<?xml version="1.0"?>
<package xmlns="http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd">
	<metadata>
		<id>Mdbc</id>
		<version>$Version</version>
		<authors>Roman Kuzmin</authors>
		<owners>Roman Kuzmin</owners>
		<projectUrl>https://github.com/nightroman/Mdbc</projectUrl>
		<licenseUrl>http://www.apache.org/licenses/LICENSE-2.0</licenseUrl>
		<requireLicenseAcceptance>false</requireLicenseAcceptance>
		<summary>$text</summary>
		<description>$text</description>
		<tags>Mongo MongoDB PowerShell Module Database</tags>
	</metadata>
</package>
"@
	# pack
	exec { NuGet pack z\Package.nuspec -NoPackageAnalysis }
}

# Check files.
task CheckFiles {
	$Pattern = '\.(cs|csproj|md|ps1|psd1|psm1|ps1xml|sln|txt|xml|gitignore)$'
	foreach ($file in git status -s) { if ($file -notmatch $Pattern) {
		Write-Warning "Illegal file: '$file'."
	}}
}

# Call tests.
task Test {
	Invoke-Build ** Tests -Result result
	assert ($result.Tasks.Count -eq 48) $result.Tasks.Count
}

# Build, test and clean all.
task . Rebuild, Test, TestHelp, Clean, CheckFiles
