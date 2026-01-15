<#
.Synopsis
	Build script, https://github.com/nightroman/Invoke-Build
#>

param(
	$Configuration = 'Release'
)

Set-StrictMode -Version 3
$_name = 'Mdbc'
$_root = "$env:ProgramFiles\PowerShell\Modules\$_name"

# Synopsis: Remove temp files.
task clean -After pushPSGallery {
	remove *.nupkg, z, Src\bin, Src\obj, README.html
}

# Synopsis: Generate meta files.
task meta -Inputs $BuildFile, Release-Notes.md -Outputs "Module\$_name.psd1", Src\Directory.Build.props -Jobs version, {
	$Project = 'https://github.com/nightroman/Mdbc'
	$Summary = 'Mdbc module - MongoDB Cmdlets for PowerShell'
	$Copyright = 'Copyright (c) Roman Kuzmin'

	Set-Content Module\$_name.psd1 @"
@{
	Author = 'Roman Kuzmin'
	ModuleVersion = '$_version'
	Description = '$Summary'
	CompanyName = 'https://github.com/nightroman'
	Copyright = '$Copyright'

	RootModule = '$_name.dll'
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
		<Product>$_name</Product>
		<Version>$_version</Version>
		<IncludeSourceRevisionInInformationalVersion>False</IncludeSourceRevisionInInformationalVersion>
	</PropertyGroup>
</Project>
"@
}

# Synopsis: Build, publish in post-build, make help.
task build meta, {
	exec { dotnet build "Src\$_name.csproj" -c $Configuration --tl:off }
}

# Synopsis: Publish the module (post-build).
task publish {
	exec { dotnet publish "Src\$_name.csproj" -c $Configuration -o $_root --no-build }
	remove "$_root\System.Management.Automation.dll", "$_root\*.deps.json"
	exec { robocopy Module $_root /s /np /xf *-Help.ps1 } (0..3)
}

# Synopsis: Build help by https://github.com/nightroman/Helps
task help -After ?build -Inputs {Get-Item Src\Commands\*, "Module\en-US\$_name-Help.ps1"} -Outputs "$_root\en-US\$_name-Help.xml" {
	. Helps.ps1
	Convert-Helps "Module\en-US\$_name-Help.ps1" $Outputs
}

# Synopsis: Convert markdown to HTML.
task markdown {
	requires -Path $env:MarkdownCss
	exec { pandoc.exe @(
		'README.md'
		'--output=README.html'
		'--from=gfm'
		'--embed-resources'
		'--standalone'
		"--css=$env:MarkdownCss"
		"--metadata=pagetitle=$_name"
	)}
}

# Synopsis: Set $Script:_version.
task version {
	($Script:_version = Get-BuildVersion Release-Notes.md '##\s+v(\d+\.\d+\.\d+)')
}

# Synopsis: Make the package.
task package markdown, version, {
	equals (Get-Module $_name -ListAvailable).Version ([Version]$_version)
	equals $_version (Get-Item "$_root\$_name.dll").VersionInfo.ProductVersion

	remove z
	$null = mkdir z\$_name

	Copy-Item -Recurse -Destination z\$_name $(
		'LICENSE'
		'README.html'
		"$_root\*"
	)

	$result = Get-ChildItem z\$_name -Recurse -File -Name | Out-String
	$sample = @'
DnsClient.dll
LICENSE
Mdbc.dll
Mdbc.pdb
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
task pushPSGallery package, {
	Publish-Module -Path z\$_name -NuGetApiKey (property NuGetApiKeyPS)
}

# Synopsis: Push repository with a version tag.
task pushRelease version, updateScript, {
	assert (!(exec {git status --short})) "Commit changes."

	exec {git push}
	exec {git tag -a "v$_version" -m "v$_version"}
	exec {git push origin "v$_version"}
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
	$ErrorView = 'NormalView'
	Invoke-Build ** Tests
}

# Synopsis: Build and clean.
task . build, clean
