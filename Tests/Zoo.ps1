
<#
.Synopsis
	Common tools used by tests.
#>

function Get-ServerVersion {
	Connect-Mdbc . test
	$command = New-MdbcData
	$command.buildInfo = ''
	$version = (Invoke-MdbcCommand $command).version
	assert ($version -match '^\d+\.\d+\.\d+$')
	[version]$version
}

# Invokes the test repeatedly with the specified contexts.
# Args: the test script block and context script blocks.
function Invoke-Test($Test)
{
	foreach(${+} in $args) {&{
		Write-Build 8 ${+}
		. ${+}
		. $Test
	}}
}

# Compares an object type with expected
function Test-Type($Value, $TypeName) {
	$name = $Value.GetType().FullName
	if (($tick = $name.IndexOf('`')) -ge 0) {$name = $name.Substring(0, $tick)}

	if ($TypeName -ne $name) {
		Write-Error -ErrorAction 1 "Expected type: $TypeName, actual type: $name"
	}
}

# Invokes a command and checks the error and the sample.
# Args: [0] script block [1] sample error wildcard.
function Test-Error {
	${private:+command}, ${private:+sample} = $args
	${private:+result} = $null
	try { & ${+command} }
	catch { ${+result} = $_ }

	if (${+result} -notlike ${+sample}) {
		Write-Error -ErrorAction 1 "`n Sample error : ${+sample}`n Result error : ${+result}"
	}
}

# Compares two dictionaries.
function Test-Table([System.Collections.IDictionary]$1, [System.Collections.IDictionary]$2, [switch]$Force) {
	if ($1.Count -ne $2.Count) {
		Write-Error -ErrorAction 1 "Different dictionary counts: $($1.Count) and $($2.Count)."
	}
	foreach($key in $1.Keys) {
		if (!$2.Contains($key)) {
			Write-Error -ErrorAction 1 "Second dictionary ($key) entry is missing."
		}
		$v1 = $1[$key]
		$v2 = $2[$key]

		if (($null -eq $v1) -and ($null -eq $v2)) {continue}

		if (($null -eq $v1) -ne ($null -eq $v2)) {
			Write-Error -ErrorAction 1 "Different dictionary ($key) nulls: $($null -eq $v1) and $($null -eq $v2)."
		}

		if ($v1.GetType() -ne $v2.GetType() -and (!$Force -or !(
			($v1 -is [System.Collections.IDictionary] -and $v2 -is [System.Collections.IDictionary]) -or
			($v1 -is [System.Collections.IList] -and $v2 -is [System.Collections.IList])))) {
			Write-Error -ErrorAction 1 "Different dictionary ($key) types: $($v1.GetType()) and $($v2.GetType())."
		}

		if ($v1 -is [System.Collections.IDictionary]) {
			try { Test-Table $v1 $v2 -Force:$Force }
			catch { Write-Error -ErrorAction 1 "Dictionary ($key): $_" }
			continue
		}

		if ($v1 -is [System.Collections.IList]) {
			try { Test-List $v1 $v2 -Force:$Force }
			catch { Write-Error -ErrorAction 1 "Dictionary ($key): $_" }
			continue
		}

		if ($v1 -cne $v2) {
			if ($Force -and $v1 -is [datetime] -and [math]::Abs(($v1 - $v2).TotalSeconds) -lt 2) {}
			else {
				Write-Error -ErrorAction 1 "Different dictionary ($key) values: ($v1) and ($v2)."
			}
		}
	}
}

# Compares two lists.
function Test-List([System.Collections.IList]$1, [System.Collections.IList]$2, [switch]$Force) {
	if ($1.Count -ne $2.Count) {
		Write-Error -ErrorAction 1 "Different list counts: $($1.Count) and $($2.Count)."
	}
	for($i = 0; $i -lt $1.Count; ++$i) {
		$v1 = $1[$i]
		$v2 = $2[$i]

		if (($null -eq $v1) -and ($null -eq $v2)) {continue}

		if (($null -eq $v1) -ne ($null -eq $v2)) {
			Write-Error -ErrorAction 1 "Different list ($i) nulls: $($null -eq $v1) and $($null -eq $v2)."
		}

		if ($v1.GetType() -ne $v2.GetType() -and (!$Force -or !(
				($v1 -is [System.Collections.IDictionary] -and $v2 -is [System.Collections.IDictionary]) -or
				($v1 -is [System.Collections.IList] -and $v2 -is [System.Collections.IList])))) {
			Write-Error -ErrorAction 1 "Different list ($i) types: $($v1.GetType()) and $($v2.GetType())."
		}

		if ($v1 -is [System.Collections.IDictionary]) {
			try { Test-Table $v1 $v2 -Force:$Force }
			catch { Write-Error -ErrorAction 1 "List ($i): $_" }
			continue
		}

		if ($v1 -is [System.Collections.IList]) {
			try { Test-List $v1 $v2 -Force:$Force }
			catch { Write-Error -ErrorAction 1 "List ($i): $_" }
			continue
		}

		if ($v1 -cne $v2) {
			if ($Force -and $v1 -is [datetime] -and [math]::Abs(($v1 - $v2).TotalSeconds) -lt 2) {}
			else {
				Write-Error -ErrorAction 1 "Different list ($i) values: ($v1) and ($v2)."
			}
		}
	}
}

# Log expression and sample, invoke expression, compare with sample
function Test-Expression($expression, $sample) {
	"$expression => $sample"
	$result = (. $expression).ToString()
	if ($result -cne $sample) {
		Write-Error -ErrorAction 1 "`n Sample : $sample`n Result : $result"
	}
}
