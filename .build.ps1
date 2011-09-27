
<#
.Synopsis
	Build script (https://github.com/nightroman/Invoke-Build)

.Description
	How to use this script and build the module:

	*) Copy MongoDB.Bson.dll and MongoDB.Driver.dll from the released zip to
	the Module directory. The C# project Mdbc.csproj assumes they are there.

	*) Get the utility script Invoke-Build.ps1 from here:
	https://github.com/nightroman/Invoke-Build

	*) Copy it to any directory in the system path. Then set location to this
	script directory and invoke the Build task:
	PS> Invoke-Build Build

	This command builds the module and installs it to the $ModuleRoot which is
	the working location of the Mdbc module. The build fails if the module is
	currently in use. Ensure it is not and then repeat.

	The build task Help fails if the help builder Helps is not installed.
	Ignore this or better get and install the module (it is really easy):
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
	exec { robocopy Module $ModuleRoot /s /np /r:0 } (0..3)
},
@{Help=1}

# Build module help by Helps (https://github.com/nightroman/Helps).
task Help -Incremental @{(Get-Item Src\Commands\*, en-US\Mdbc.dll-Help.ps1) = "$ModuleRoot\en-US\Mdbc.dll-Help.xml"} {
	. Helps.ps1
	Convert-Helps en-US\Mdbc.dll-Help.ps1 $Outputs
}

# Test help examples.
task TestHelpExample {
	. Helps.ps1
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
task UpdateScripts -Partial @{{
	Get-Command Update-MongoFiles.ps1, Get-MongoFile.ps1 | %{ $_.Definition }
} = {process{
	"Scripts\$(Split-Path -Leaf $_)"
}}} {process{
	Copy-Item $_ $$
}}

# Make a task for each script in the Tests directory and add to the jobs.
task Test @(
	Get-ChildItem Tests -Filter Test-*.ps1 | .{process{
		# add a task
		task $_.Name (Invoke-Expression "{ $($_.FullName) }")
		# add it as a job
		$_.Name
	}}
)

# git pull on the C# driver repo
task PullDriver {
	assert $env:MongoDBCSharpDriverRepo
	Set-Location $env:MongoDBCSharpDriverRepo
	exec { git pull }
}

# Build the C# driver from sources and copy its assemblies to Module
task BuildDriver {
	assert $env:MongoDBCSharpDriverRepo
	exec { MSBuild $env:MongoDBCSharpDriverRepo\CSharpDriver-2010.sln /t:Build /p:Configuration=Release }
	Copy-Item $env:MongoDBCSharpDriverRepo\Driver\bin\Release\*.dll Module
}

# Clean the C# driver sources
task CleanDriver {
	assert $env:MongoDBCSharpDriverRepo
	exec { MSBuild $env:MongoDBCSharpDriverRepo\CSharpDriver-2010.sln /t:Clean /p:Configuration=Release }
}

# Pull the latest driver, build it, then build Mdbc, test and clean all
task Driver PullDriver, BuildDriver, Build, Test, Clean, CleanDriver

# <https://github.com/nightroman/Invoke-Build/wiki/Partial-Incremental-Tasks>
try { Markdown.tasks.ps1 }
catch { task ConvertMarkdown; task RemoveMarkdownHtml }

# Make the public zip
task Zip ConvertMarkdown, @{UpdateScripts=1}, {
	$zip = "Mdbc.1.0.0.rc2.zip"

	# make zip
	exec { robocopy $ModuleRoot z\Mdbc /s } (0..3)
	exec { robocopy Scripts z\Mdbc\Scripts } (0..3)
	Copy-Item License.txt, *.htm z\Mdbc
	Push-Location z
	$content = exec { & 7z a $zip * } | ?{ $_ -match '^Compressing'} | Out-String
	$content
	Copy-Item $zip ..
	Pop-Location
	Remove-Item z -Recurse -Force

	# test content if ConvertMarkdown is done
	assert ((error ConvertMarkdown) -or ($content -eq @'
Compressing  Mdbc\en-US\about_Mdbc.help.txt
Compressing  Mdbc\en-US\Mdbc.dll-Help.xml
Compressing  Mdbc\License.C# Driver.txt
Compressing  Mdbc\License.txt
Compressing  Mdbc\Mdbc.dll
Compressing  Mdbc\Mdbc.Format.ps1xml
Compressing  Mdbc\Mdbc.psd1
Compressing  Mdbc\Mdbc.psm1
Compressing  Mdbc\MongoDB.Bson.dll
Compressing  Mdbc\MongoDB.Driver.dll
Compressing  Mdbc\README.htm
Compressing  Mdbc\Scripts\Get-MongoFile.ps1
Compressing  Mdbc\Scripts\Update-MongoFiles.ps1

'@))

	# git status
	$status = git status -s
	if ($status) { Write-Warning $status }
},
RemoveMarkdownHtml

# Build, test and clean all.
task . Build, Test, TestHelp, Clean
