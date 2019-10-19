<#
.Synopsis
	Build script (https://github.com/nightroman/Invoke-Build)
#>

param(
	$Configuration = 'Release',

	[ValidateSet('net452', 'netstandard2.0')]
	$TargetFramework = 'net452'
)

$ModuleName = 'Mdbc'

# module root for publish
# netX
$ModuleRoot1 = if ($env:ProgramW6432) {$env:ProgramW6432} else {$env:ProgramFiles}
$ModuleRoot1 = "$ModuleRoot1\WindowsPowerShell\Modules\$ModuleName"
# netstandardX
$ModuleRoot2 = Join-Path ([Environment]::GetFolderPath('MyDocuments')) PowerShell\Modules\$ModuleName
# current
if ($TargetFramework -eq 'net452') {
	$ModuleRoot = $ModuleRoot1
}
else {
	$ModuleRoot = $ModuleRoot2
}

# Get version from release notes.
function Get-Version {
	switch -Regex -File Release-Notes.md {'##\s+v(\d+\.\d+\.\d+)' {return $Matches[1]} }
}

$MetaParam = @{
	Inputs = '.build.ps1', 'Release-Notes.md'
	Outputs = "Module\$ModuleName.psd1", 'Src\AssemblyInfo.cs'
}

# Synopsis: Generate or update meta files.
task Meta @MetaParam {
	$Version = Get-Version
	$Project = 'https://github.com/nightroman/Mdbc'
	$Summary = 'Mdbc module - MongoDB Cmdlets for PowerShell'
	$Copyright = 'Copyright (c) 2011-2019 Roman Kuzmin'

	Set-Content Module\$ModuleName.psd1 @"
@{
	Author = 'Roman Kuzmin'
	ModuleVersion = '$Version'
	Description = '$Summary'
	CompanyName = '$Project'
	Copyright = '$Copyright'

	RootModule = '$ModuleName.dll'
	RequiredAssemblies = 'System.Runtime.InteropServices.RuntimeInformation.dll', 'MongoDB.Bson.dll', 'MongoDB.Driver.Core.dll', 'MongoDB.Driver.dll', 'MongoDB.Driver.Legacy.dll'

	PowerShellVersion = '3.0'
	DotNetFrameworkVersion = '4.0'
	GUID = '12c81cd8-bde3-4c91-a292-e6c4f868106a'

	PrivateData = @{
		PSData = @{
			Tags = 'Mongo', 'MongoDB', 'Database'
			LicenseUri = 'http://www.apache.org/licenses/LICENSE-2.0'
			ProjectUri = 'https://github.com/nightroman/Mdbc'
			ReleaseNotes = 'https://github.com/nightroman/Mdbc/blob/master/Release-Notes.md'
		}
	}
}
"@

	Set-Content Src\AssemblyInfo.cs @"
using System;
using System.Reflection;
using System.Runtime.InteropServices;

[assembly: AssemblyProduct("$ModuleName")]
[assembly: AssemblyVersion("$Version")]
[assembly: AssemblyTitle("$Summary")]
[assembly: AssemblyCompany("$Project")]
[assembly: AssemblyCopyright("$Copyright")]

[assembly: ComVisible(false)]
[assembly: CLSCompliant(false)]
"@
}

# Synopsis: Build the project.
task Build Meta, {
	exec { dotnet build Src\$ModuleName.csproj -c $Configuration -f $TargetFramework }
},
Publish

# Synopsis: Build all frameworks.
task Build2 {
	Invoke-Build Build -Configuration $Configuration -TargetFramework net452
	Invoke-Build Build -Configuration $Configuration -TargetFramework netstandard2.0
}

# Synopsis: Publish the module.
task Publish {
	if ($TargetFramework -eq 'net452') {
		remove $ModuleRoot
		exec { robocopy Module $ModuleRoot /s /np /r:0 /xf *-Help.ps1 } (0..3)
		exec { robocopy Src\bin\$Configuration\$TargetFramework $ModuleRoot /s /np /r:0 } (0..3)
	}
	else {
		exec { dotnet publish Src\$ModuleName.csproj -c $Configuration -f $TargetFramework }
		remove $ModuleRoot
		exec { robocopy Module $ModuleRoot /s /np /r:0 /xf *-Help.ps1 } (0..3)
		exec { robocopy Src\bin\$Configuration\$TargetFramework\publish $ModuleRoot /s /np /r:0 } (0..3)

		# tweak manifest requirements
		Import-Module PsdKit
		$xml = Import-PsdXml $ModuleRoot\Mdbc.psd1
		Set-Psd $xml '5.1' 'Data/Table/Item[@Key="PowerShellVersion"]'
		Set-Psd $xml '4.7.1' 'Data/Table/Item[@Key="DotNetFrameworkVersion"]'
		Export-PsdXml $ModuleRoot\Mdbc.psd1 $xml
	}
}

# Synopsis: Remove temp files.
task Clean {
	remove "$ModuleName.*.nupkg", z, Src\bin, Src\obj, README.htm, Release-Notes.htm
}

# Synopsis: Build help by Helps (https://github.com/nightroman/Helps).
task Help @{
	Inputs = {Get-Item Src\Commands\*, Module\en-US\$ModuleName.dll-Help.ps1}
	Outputs = {"$ModuleRoot\en-US\$ModuleName.dll-Help.xml"}
	Jobs = {
		. Helps.ps1
		Convert-Helps Module\en-US\$ModuleName.dll-Help.ps1 $Outputs
	}
}

# Synopsis: Build and test help.
task TestHelpExample {
	. Helps.ps1
	Test-Helps Module\en-US\$ModuleName.dll-Help.ps1
}

# Synopsis: Convert markdown files to HTML.
# <http://johnmacfarlane.net/pandoc/>
task Markdown {
	function Convert-Markdown($Name) {pandoc.exe --standalone --from=gfm "--output=$Name.htm" "--metadata=pagetitle=$Name" "$Name.md"}
	exec { Convert-Markdown README }
	exec { Convert-Markdown Release-Notes }
}

# Synopsis: Set $script:Version.
task Version {
	($script:Version = Get-Version)
	# manifest version
	$data = & ([scriptblock]::Create([IO.File]::ReadAllText("$ModuleRoot\$ModuleName.psd1")))
	assert ($data.ModuleVersion -eq $script:Version)
	# assembly version
	assert ((Get-Item $ModuleRoot\$ModuleName.dll).VersionInfo.FileVersion -eq ([Version]"$script:Version.0"))
}

# Synopsis: Make the package in z\tools.
task Package Markdown, ?UpdateScript, {
	remove z
	$null = mkdir z\tools\$ModuleName\Scripts

	Copy-Item -Recurse -Destination z\tools\$ModuleName `
	LICENSE.txt,
	README.htm,
	Release-Notes.htm,
	$ModuleRoot\*

	Copy-Item -Destination z\tools\$ModuleName\Scripts `
	.\Scripts\Mdbc.ps1,
	.\Scripts\Get-MongoFile.ps1,
	.\Scripts\Update-MongoFiles.ps1,
	.\Scripts\Mdbc.ArgumentCompleters.ps1
}

# Synopsis: Make NuGet package.
task NuGet Package, Version, {
	$text = @'
Mdbc is the PowerShell module based on the official MongoDB C# driver.
It makes MongoDB scripting in PowerShell easier and provides some extra
features like bson/json file collections which do not require MongoDB.
'@
	# nuspec
	Set-Content z\Package.nuspec @"
<?xml version="1.0"?>
<package xmlns="http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd">
	<metadata>
		<id>$ModuleName</id>
		<version>$Version</version>
		<authors>Roman Kuzmin</authors>
		<owners>Roman Kuzmin</owners>
		<projectUrl>https://github.com/nightroman/Mdbc</projectUrl>
		<license type="expression">Apache-2.0</license>
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

# Synopsis: Push to the repository with a version tag.
task PushRelease Version, {
	$changes = exec { git status --short }
	assert (!$changes) "Please, commit changes."

	exec { git push }
	exec { git tag -a "v$Version" -m "v$Version" }
	exec { git push origin "v$Version" }
}

# Synopsis: Make and push the NuGet package.
task PushNuGet NuGet, {
	assert ($TargetFramework -eq 'net452')
	exec { NuGet push "$ModuleName.$Version.nupkg" -Source nuget.org }
},
Clean

# Synopsis: Make and push the PSGallery package.
task PushPSGallery Package, Version, {
	assert ($TargetFramework -eq 'netstandard2.0')
	$NuGetApiKey = Read-Host NuGetApiKey
	Publish-Module -Path z/tools/$ModuleName -NuGetApiKey $NuGetApiKey
},
Clean

# Synopsis: Test synopsis of each cmdlet and warn about unexpected.
task TestHelpSynopsis {
	Import-Module Mdbc
	Get-Command *-Mdbc* -CommandType cmdlet | Get-Help | .{process{
		if (!$_.Synopsis.EndsWith('.')) {
			Write-Warning "$($_.Name) : unexpected/missing synopsis"
		}
	}}
}

# Synopsis: Update help then run help tests.
task TestHelp Help, TestHelpExample, TestHelpSynopsis

$UpdateScriptInputs = @(
	'Get-MongoFile.ps1'
	'Mdbc.ps1'
	'Mdbc.ArgumentCompleters.ps1'
	'Update-MongoFiles.ps1'
)

# Synopsis: Copy external scripts to the project.
# It fails if a script is missing.
task UpdateScript -Partial `
-Inputs { Get-Command $UpdateScriptInputs | .{process{ $_.Definition }} } `
-Outputs {process{ "Scripts\$(Split-Path -Leaf $_)" }} `
{process{ Copy-Item $_ $2 }}

# Synopsis: Check expected files.
task CheckFiles {
	$Pattern = '\.(cs|csproj|lock|md|ps1|psd1|psm1|ps1xml|sln|txt|xml|gitignore)$'
	foreach ($file in git status -s) { if ($file -notmatch $Pattern) {
		Write-Warning "Illegal file: '$file'."
	}}
}

# Synopsis: Remove test.test* collections
task CleanTest {
	Import-Module Mdbc
	foreach($Collection in Connect-Mdbc . test *) {
		if ($Collection.Name -like 'test*') {
			$null = $Collection.Drop()
		}
	}
}

# Synopsis: Test in the current PowerShell.
task Test {
	Invoke-Build ** Tests
},
CleanTest

# Synopsis: Test in PowerShell v6.
task Test6 -If $env:powershell6 {
	exec {& $env:powershell6 -NoProfile -Command Invoke-Build Test}
}

# Synopsis: Build, test and clean all.
task . Build2, TestHelp, Test, Test6, Clean, CheckFiles
