
# Add a task for each test script and collect names to be used as jobs.
$tests = foreach($_ in Get-ChildItem -Name -Filter Test-*.ps1) {
	task $_ ([scriptblock]::Create("./$_"))
	$_
}

# Call tests. Use test names as jobs.
task . $tests
