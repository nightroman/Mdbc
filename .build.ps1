
<#
.Synopsis
	Build script (https://github.com/nightroman/Invoke-Build)
#>

param(
	$Configuration = 'Release',
	$TargetFrameworkVersion = 'v4.5'
)

$ModuleName = 'Mdbc'

# Module directory.
$ModuleRoot = Join-Path ([Environment]::GetFolderPath('MyDocuments')) WindowsPowerShell\Modules\$ModuleName

# Get version from release notes.
function Get-Version {
	switch -Regex -File Release-Notes.md {'##\s+v(\d+\.\d+\.\d+)' {return $Matches[1]} }
}

task Init Meta, {
	exec {paket.exe install}
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
	$Copyright = 'Copyright (c) 2011-2017 Roman Kuzmin'

	Set-Content Module\$ModuleName.psd1 @"
@{
	Author = 'Roman Kuzmin'
	ModuleVersion = '$Version'
	Description = '$Summary'
	CompanyName = '$Project'
	Copyright = '$Copyright'

	ModuleToProcess = '$ModuleName.dll'
	RequiredAssemblies = 'System.Runtime.InteropServices.RuntimeInformation.dll', 'MongoDB.Bson.dll', 'MongoDB.Driver.Core.dll', 'MongoDB.Driver.dll', 'MongoDB.Driver.Legacy.dll'

	PowerShellVersion = '2.0'
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

# Synopsis: Build and trigger PostBuild.
task Build Meta, {
	use * MSBuild.exe
	exec { MSBuild.exe Src\$ModuleName.csproj /t:Build /p:Configuration=$Configuration /p:TargetFrameworkVersion=$TargetFrameworkVersion}
}

# Synopsis: Copy files to the module root.
# It is called from the post build event.
task PostBuild {
	exec { robocopy Module $ModuleRoot /s /np /r:0 /xf *-Help.ps1 } (0..3)
	Copy-Item -Destination $ModuleRoot -LiteralPath @(
		"Src\Bin\$Configuration\$ModuleName.dll"
		'packages\mongocsharpdriver\lib\net45\MongoDB.Driver.Legacy.dll'
		'packages\MongoDB.Bson\lib\net45\MongoDB.Bson.dll'
		'packages\MongoDB.Driver\lib\net45\MongoDB.Driver.dll'
		'packages\MongoDB.Driver.Core\lib\net45\MongoDB.Driver.Core.dll'
		'packages\System.Runtime.InteropServices.RuntimeInformation\lib\net45\System.Runtime.InteropServices.RuntimeInformation.dll'
	)
}

# Synopsis: Remove temp files.
task Clean {
	Remove-Item -Force -Recurse -ErrorAction 0 `
	"$ModuleName.*.nupkg",
	z, Src\bin, Src\obj, README.htm, Release-Notes.htm
}

# Synopsis: Build help by Helps (https://github.com/nightroman/Helps).
task Help -Inputs (
	Get-Item Src\Commands\*, Module\en-US\$ModuleName.dll-Help.ps1
) -Outputs (
	"$ModuleRoot\en-US\$ModuleName.dll-Help.xml"
) {
	. Helps.ps1
	Convert-Helps Module\en-US\$ModuleName.dll-Help.ps1 $Outputs
}

# Synopsis: Build and test help.
task TestHelpExample {
	. Helps.ps1
	Test-Helps Module\en-US\$ModuleName.dll-Help.ps1
}

# Synopsis: Convert markdown files to HTML.
# <http://johnmacfarlane.net/pandoc/>
task Markdown {
	exec { pandoc.exe --standalone --from=markdown_strict --output=README.htm README.md }
	exec { pandoc.exe --standalone --from=markdown_strict --output=Release-Notes.htm Release-Notes.md }
}

# Synopsis: Set $script:Version.
task Version {
	($script:Version = Get-Version)
	# module version
	assert ((Get-Module $ModuleName -ListAvailable).Version -eq ([Version]$script:Version))
	# assembly version
	assert ((Get-Item $ModuleRoot\$ModuleName.dll).VersionInfo.FileVersion -eq ([Version]"$script:Version.0"))
}

# Synopsis: Make the package in z\tools.
task Package Markdown, (job UpdateScript -Safe), {
	Remove-Item [z] -Force -Recurse
	$null = mkdir z\tools\$ModuleName\en-US, z\tools\$ModuleName\Scripts

	Copy-Item -Destination z\tools\$ModuleName `
	LICENSE.txt,
	README.htm,
	Release-Notes.htm,
	$ModuleRoot\$ModuleName.dll,
	$ModuleRoot\$ModuleName.psd1,
	$ModuleRoot\MongoDB.Driver.Legacy.dll,
	$ModuleRoot\MongoDB.Bson.dll,
	$ModuleRoot\MongoDB.Driver.dll,
	$ModuleRoot\MongoDB.Driver.Core.dll,
	$ModuleRoot\System.Runtime.InteropServices.RuntimeInformation.dll

	Copy-Item -Destination z\tools\$ModuleName\en-US `
	$ModuleRoot\en-US\about_$ModuleName.help.txt,
	$ModuleRoot\en-US\$ModuleName.dll-Help.xml

	Copy-Item -Destination z\tools\$ModuleName\Scripts `
	.\Scripts\Mdbc.ps1,
	.\Scripts\Get-MongoFile.ps1,
	.\Scripts\Update-MongoFiles.ps1,
	.\Scripts\Mdbc.ArgumentCompleters.ps1
}

# Synopsis: Make NuGet package.
task NuGet Package, Version, {
	$text = @'
Windows PowerShell module based on the official MongoDB C# driver v2.x
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
	exec { NuGet push "$ModuleName.$Version.nupkg" -Source nuget.org }
},
Clean

# Synopsis: Remove test.test* collections
task CleanTest {
	Import-Module Mdbc
	foreach($Collection in Connect-Mdbc . test *) {
		if ($Collection.Name -like 'test*') {
			$null = $Collection.Drop()
		}
	}
}

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
	$Pattern = '\.(cs|csproj|md|ps1|psd1|psm1|ps1xml|sln|txt|xml|gitignore)$'
	foreach ($file in git status -s) { if ($file -notmatch $Pattern) {
		Write-Warning "Illegal file: '$file'."
	}}
}

# Synopsis: Call tests and test the expected count.
task Test {
	Invoke-Build ** Tests -Result result
},
CleanTest

# Synopsis: Build, test and clean all.
task . Build, TestHelp, Test, Clean, CheckFiles
