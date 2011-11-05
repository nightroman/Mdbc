
# Add a task for each test script.
foreach($_ in Get-ChildItem -Name -Filter Test-*.ps1) {
	task $_ ([scriptblock]::Create("./$_"))
}
