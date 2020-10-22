
$Version = $PSVersionTable.PSVersion.Major

task TabExpansion2.v5 -If ($Version -ge 5) {
	exec {ib.cmd * TabExpansion2.v5.build.ps1}
}
