
<#
.Synopsis
	Build script (https://github.com/nightroman/Invoke-Build)
#>

param
(
	$Configuration = 'Release'
)

$ModuleRoot = Join-Path ([Environment]::GetFolderPath('MyDocuments')) WindowsPowerShell\Modules\Mdbc

# Use MSBuild.
use Framework\v4.0.30319 MSBuild

# Build, test and clean all.
task . Build, Test, TestHelp, Clean

# Build all.
task Build {
	exec { MSBuild Src\Mdbc.csproj /t:Build /p:Configuration=Release }
}

# Clean all.
task Clean {
	Remove-Item Src\bin, Src\obj, Module\Mdbc.dll -Recurse -Force -ErrorAction 0
}

# Copy all to the module root directory and then build help.
# It is called as the post-build event of Mdbc.csproj.
task PostBuild {
	Copy-Item Src\Bin\$Configuration\Mdbc.dll Module
	exec { robocopy Module $ModuleRoot /mir /np /r:0 } (0..3)
},
Help

# Build module help by Helps (https://github.com/nightroman/Helps).
task Help `
-Inputs (Get-Item Src\Commands\*, en-US\Mdbc.dll-Help.ps1) `
-Outputs $ModuleRoot\en-US\Mdbc.dll-Help.xml `
{
	Import-Module Helps
	Convert-Helps en-US\Mdbc.dll-Help.ps1 $Outputs
}

# Test help examples.
task TestHelpExample {
	Import-Module Helps
	Test-Helps en-US\Mdbc.dll-Help.ps1
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
task CopyScripts `
-Inputs { Get-Command Update-MongoFiles.ps1, Get-MongoFile.ps1 | %{ $_.Definition } } `
-Outputs {process{ "Scripts\$(Split-Path -Leaf $_)" }} `
{process{ Copy-Item $_ $$ }}

task Test @(
	Get-ChildItem Tests -Filter Test-*.ps1 | .{process{
		# add a task
		task $_.Name (Invoke-Expression "{ $($_.FullName) }")
		# add it as a job
		$_.Name
	}}
)

task PullDriver {
	assert $env:MongoDBCSharpDriverRepo
	Set-Location $env:MongoDBCSharpDriverRepo
	exec { git pull }
}

task BuildDriver {
	assert $env:MongoDBCSharpDriverRepo
	exec { MSBuild $env:MongoDBCSharpDriverRepo\CSharpDriver-2010.sln /t:Build /p:Configuration=Release }
	Copy-Item $env:MongoDBCSharpDriverRepo\Driver\bin\Release\*.dll Module
}

task CleanDriver {
	assert $env:MongoDBCSharpDriverRepo
	exec { MSBuild $env:MongoDBCSharpDriverRepo\CSharpDriver-2010.sln /t:Clean /p:Configuration=Release }
}

task Driver PullDriver, BuildDriver, Build, Test, Clean, CleanDriver

task ConvertMarkdown `
-Inputs { Get-ChildItem -Filter *.md } `
-Outputs {process{ [System.IO.Path]::ChangeExtension($_, 'htm') }} `
{process{
	Convert-Markdown.ps1 $_ $$
}}

task Zip @{ConvertMarkdown=1}, {
	$zip = "Mdbc.1.0.0.rc0.zip"
	exec { robocopy $ModuleRoot z\Mdbc /s } (0..3)
	exec { robocopy Scripts z\Mdbc\Scripts } (0..3)
	Copy-Item License.txt, *.htm z\Mdbc
	Push-Location z
	exec { & 7z a $zip * }
	Copy-Item $zip ..
	Pop-Location
	Remove-Item z -Recurse -Force
	Remove-Item *.htm
}
