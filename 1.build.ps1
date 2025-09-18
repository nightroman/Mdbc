<#
.Synopsis
	Build script, https://github.com/nightroman/Invoke-Build
#>

param(
	$Configuration = 'Release'
)

Set-StrictMode -Version 3
$ModuleName = 'Mdbc'
$ModuleRoot = "$env:ProgramFiles\PowerShell\Modules\$ModuleName"

# Synopsis: Generate meta files.
task meta -Inputs $BuildFile, Release-Notes.md -Outputs "Module\$ModuleName.psd1", Src\Directory.Build.props -Jobs version, {
	$Project = 'https://github.com/nightroman/Mdbc'
	$Summary = 'Mdbc module - MongoDB Cmdlets for PowerShell'
	$Copyright = 'Copyright (c) Roman Kuzmin'

	Set-Content Module\$ModuleName.psd1 @"
@{
	Author = 'Roman Kuzmin'
	ModuleVersion = '$Version'
	Description = '$Summary'
	CompanyName = 'https://github.com/nightroman'
	Copyright = '$Copyright'

	RootModule = '$ModuleName.dll'
	RequiredAssemblies = 'MongoDB.Bson.dll', 'MongoDB.Driver.dll'

	PowerShellVersion = '7.4'
	GUID = '12c81cd8-bde3-4c91-a292-e6c4f868106a'

	AliasesToExport = @()
	VariablesToExport = @()
	FunctionsToExport = @()
	CmdletsToExport = @(
		'Add-MdbcCollection'
		'Add-MdbcData'
		'Connect-Mdbc'
		'Export-MdbcData'
		'Get-MdbcCollection'
		'Get-MdbcData'
		'Get-MdbcDatabase'
		'Import-MdbcData'
		'Invoke-MdbcAggregate'
		'Invoke-MdbcCommand'
		'New-MdbcData'
		'Register-MdbcClassMap'
		'Remove-MdbcCollection'
		'Remove-MdbcData'
		'Remove-MdbcDatabase'
		'Rename-MdbcCollection'
		'Set-MdbcData'
		'Update-MdbcData'
		'Use-MdbcTransaction'
		'Watch-MdbcChange'
	)

	PrivateData = @{
		PSData = @{
			Tags = 'Mongo', 'MongoDB', 'Database'
			ProjectUri = '$Project'
			LicenseUri = 'http://www.apache.org/licenses/LICENSE-2.0'
			ReleaseNotes = '$Project/blob/main/Release-Notes.md'
		}
	}
}
"@

	Set-Content Src\Directory.Build.props @"
<Project>
	<PropertyGroup>
		<Company>$Project</Company>
		<Copyright>$Copyright</Copyright>
		<Description>$Summary</Description>
		<Product>$ModuleName</Product>
		<Version>$Version</Version>
		<IncludeSourceRevisionInInformationalVersion>False</IncludeSourceRevisionInInformationalVersion>
	</PropertyGroup>
</Project>
"@
}

# Synopsis: Remove temp files.
task clean -After pushPSGallery {
	remove z, Src\bin, Src\obj, README.html
}

# Synopsis: Build, publish in post-build, make help.
task build meta, {
	exec {dotnet build "Src\$ModuleName.csproj" -c $Configuration}
}

# Synopsis: Publish the module (post-build).
task publish {
	exec {dotnet publish "Src\$ModuleName.csproj" --no-build -c $Configuration -o $ModuleRoot}
	remove "$ModuleRoot\System.Management.Automation.dll", "$ModuleRoot\*.deps.json"

	exec {robocopy Module $ModuleRoot /s /xf *-Help.ps1} (0..3)
}

# Synopsis: Build help by https://github.com/nightroman/Helps
task help -After ?build -Inputs {Get-Item Src\Commands\*, "Module\en-US\$ModuleName-Help.ps1"} -Outputs "$ModuleRoot\en-US\$ModuleName-Help.xml" {
	. Helps.ps1
	Convert-Helps "Module\en-US\$ModuleName-Help.ps1" $Outputs
}

# Synopsis: Set $Script:Version.
task version {
	($Script:Version = Get-BuildVersion Release-Notes.md '##\s+v(\d+\.\d+\.\d+)')
}

# Synopsis: Convert markdown to HTML.
task markdown {
	requires -Environment MarkdownCss -Path $env:MarkdownCss
	exec {pandoc.exe @(
		'README.md'
		'--output=README.html'
		'--from=gfm'
		'--embed-resources'
		'--standalone'
		"--css=$env:MarkdownCss"
		"--metadata=pagetitle=$ModuleName"
	)}
}

# Synopsis: Make the package.
task package markdown, version, {
	equals (Get-Module $ModuleName -ListAvailable).Version ([Version]$Version)
	equals (Get-Item $ModuleRoot\$ModuleName.dll).VersionInfo.FileVersion "$Version.0"

	remove z
	exec {robocopy $ModuleRoot z\$ModuleName /s /xf *.pdb} 1

	Copy-Item LICENSE, README.html -Destination z\$ModuleName

	$result = Get-ChildItem z\$ModuleName -Recurse -File -Name | Out-String
	$sample = @'
DnsClient.dll
LICENSE
Mdbc.dll
Mdbc.psd1
Microsoft.Extensions.Logging.Abstractions.dll
MongoDB.Bson.dll
MongoDB.Driver.dll
README.html
SharpCompress.dll
Snappier.dll
ZstdSharp.dll
en-US\about_Mdbc.help.txt
en-US\Mdbc-Help.xml
'@
	Assert-SameFile.ps1 -Text $sample $result $env:MERGE
}

# Synopsis: Make and push the PSGallery package.
task pushPSGallery package, test, {
	$NuGetApiKey = Read-Host NuGetApiKey
	Publish-Module -Path z\$ModuleName -NuGetApiKey $NuGetApiKey
}

# Synopsis: Push repository with a version tag.
task pushRelease version, updateScript, {
	assert (!(exec {git status --short})) "Commit changes."

	exec {git push}
	exec {git tag -a "v$Version" -m "v$Version"}
	exec {git push origin "v$Version"}
}

# Synopsis: Copy external scripts to sources.
task updateScript {
	Assert-SameFile.ps1 Scripts/Mdbc.ArgumentCompleters.ps1 (Get-Command Mdbc.ArgumentCompleters.ps1).Definition
	Assert-SameFile.ps1 Scripts/Update-MongoFiles.ps1 (Get-Command Update-MongoFiles.ps1).Definition
}

# Synopsis: Remove test.test* collections
task cleanTest -After test {
	Import-Module Mdbc
	foreach($name in Connect-Mdbc . test *) {
		if ($name -like 'test*') {
			Remove-MdbcCollection $name
		}
	}
}

# Synopsis: Run tests.
task test {
	Invoke-Build ** Tests
}

# Synopsis: Build and clean.
task . build, clean
