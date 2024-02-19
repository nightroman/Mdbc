<#
.Synopsis
	Build script, https://github.com/nightroman/Invoke-Build
#>

param(
	$Configuration = 'Release'
)

Set-StrictMode -Version 3
$ModuleName = 'Mdbc'
$ModuleRoot = "$env:ProgramFiles\WindowsPowerShell\Modules\$ModuleName"

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
	RequiredAssemblies = 'MongoDB.Bson.dll', 'MongoDB.Driver.Core.dll', 'MongoDB.Driver.dll'

	PowerShellVersion = '5.1'
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
	remove z, Src\bin, Src\obj, README.htm
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

# Synopsis: Set $script:Version.
task version {
	($script:Version = switch -Regex -File Release-Notes.md {'##\s+v(\d+\.\d+\.\d+)' {$Matches[1]; break}})
}

# Synopsis: Convert markdown to HTML.
task markdown {
	requires -Environment MarkdownCss -Path $env:MarkdownCss
	exec {pandoc.exe @(
		'README.md'
		'--output=README.htm'
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

	Copy-Item LICENSE -Destination z\$ModuleName
	Move-Item README.htm -Destination z\$ModuleName

	$result = Get-ChildItem z\$ModuleName -Recurse -File -Name | Out-String
	$sample = @'
AWSSDK.Core.dll
AWSSDK.SecurityToken.dll
DnsClient.dll
LICENSE
Mdbc.dll
Mdbc.psd1
Microsoft.Bcl.AsyncInterfaces.dll
Microsoft.Extensions.Logging.Abstractions.dll
Microsoft.Win32.Registry.dll
MongoDB.Bson.dll
MongoDB.Driver.Core.dll
MongoDB.Driver.dll
MongoDB.Libmongocrypt.dll
README.htm
SharpCompress.dll
Snappier.dll
System.Buffers.dll
System.Memory.dll
System.Numerics.Vectors.dll
System.Runtime.CompilerServices.Unsafe.dll
System.Security.AccessControl.dll
System.Security.Principal.Windows.dll
System.Text.Encoding.CodePages.dll
System.Threading.Tasks.Extensions.dll
ZstdSharp.dll
en-US\about_Mdbc.help.txt
en-US\Mdbc-Help.xml
'@
	Assert-SameFile.ps1 -Text $sample $result $env:MERGE
}

# Synopsis: Make and push the PSGallery package.
task pushPSGallery package, {
	$NuGetApiKey = Read-Host NuGetApiKey
	Publish-Module -Path z\$ModuleName -NuGetApiKey $NuGetApiKey
}

# Synopsis: Push repository with a version tag.
task pushRelease version, updateScript, {
	$changes = exec {git status --short}
	assert (!$changes) "Please, commit changes."

	exec {git push}
	exec {git tag -a "v$Version" -m "v$Version"}
	exec {git push origin "v$Version"}
}

# Synopsis: Copy external scripts to sources.
task updateScript @{
	Partial = $true
	Inputs = {
		Get-Command Mdbc.ArgumentCompleters.ps1, Update-MongoFiles.ps1 |
		.{process{$_.Definition}}
	}
	Outputs = {process{
		$2 = "Scripts\$(Split-Path -Leaf $_)"
		$item1 = Get-Item -LiteralPath $_
		$item2 = Get-Item -LiteralPath $2
		if ($item1.LastWriteTimeUtc -lt $item2.LastWriteTimeUtc) {
			Write-Warning "Input is older: $_ $2"
			Assert-SameFile $_ $2
			Copy-Item $_ $2
		}
		$2
	}}
	Jobs = {process{
		Copy-Item $_ $2
	}}
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

# Synopsis: Test Desktop.
task desktop -After pushPSGallery {
	exec {powershell -NoProfile -Command Invoke-Build test}
}

# Synopsis: Test Core.
task core -After pushPSGallery {
	exec {pwsh -NoProfile -Command Invoke-Build test}
}

# Synopsis: Test current PowerShell.
task test {
	Invoke-Build ** Tests
}

# Synopsis: Build and clean.
task . build, clean
