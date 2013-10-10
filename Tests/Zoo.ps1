
<#
.Synopsis
	Common tools used by tests.
#>

# Invokes several tests with different context functions
function Invoke-Test([scriptblock]$Test)
{
	foreach(${+} in $args) {&{
		Write-Build 8 "At $(${+}.File):$(${+}.StartPosition.StartLine)"
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
		Write-Error -ErrorAction Stop "Expected type: $TypeName, actual type: $name"
	}
}

# Compares an expected error message
function Test-Error($Command, $Pattern) {
	$err = ''
	try { & $Command }
	catch { $err = "$_" }

	if ($err -notlike $Pattern) {
		Write-Error -ErrorAction Stop "Expected error: [[$Pattern]], actual: [[$err]]."
	}
}

# Compares two dictionaries
function Test-Dictionary([System.Collections.IDictionary]$1, [System.Collections.IDictionary]$2) {
	if ($1.Count -ne $2.Count) {
		Write-Error -ErrorAction Stop "Different counts: $($1.Count) and $($2.Count)."
	}
	foreach($key in $1.Keys) {
		if (!$2.Contains($key)) {
			Write-Error -ErrorAction Stop "Second dictionary is missing key '$key'."
		}
		$v1 = $1[$key]
		$v2 = $2[$key]

		if (($null -eq $v1) -and ($null -eq $v2)) {continue}

		if (($null -eq $v1) -ne ($null -eq $v2)) {
			Write-Error -ErrorAction Stop "Key '$key' has different nulls: $($null -eq $v1) and $($null -eq $v2)."
		}

		if ($v1.GetType() -ne $v2.GetType()) {
			Write-Error -ErrorAction Stop "Key '$key' has different types: $($v1.GetType()) and $($v2.GetType())."
		}

		if ($v1 -is [System.Collections.IDictionary]) {
			Test-Dictionary $v1 $v2
			continue
		}

		if ($v1 -cne $v2) {
			Write-Error -ErrorAction Stop "Key '$key' has different values: '$v1' and '$v2'."
		}
	}
}

# Compares two arrays. -Force: treat similar types equal.
function Test-Array([object[]]$1, [object[]]$2, [switch]$Force) {
	if ($1.Count -ne $2.Count) {
		Write-Error -ErrorAction Stop "Different counts: $($1.Count) and $($2.Count)."
	}
	for($i = 0; $i -lt $1.Count; ++$i) {
		$v1 = $1[$i]
		$v2 = $2[$i]

		if (($null -eq $v1) -and ($null -eq $v2)) {continue}

		if (($null -eq $v1) -ne ($null -eq $v2)) {
			Write-Error -ErrorAction Stop "Index '$i': different nulls: $($null -eq $v1) and $($null -eq $v2)."
		}

		if ($Force -and $v1 -is [System.Collections.IDictionary] -and $v2 -is [System.Collections.IDictionary]) {
			Test-Dictionary $v1 $v2
			continue
		}

		if ($v1.GetType() -ne $v2.GetType()) {
			Write-Error -ErrorAction Stop "Index '$i': different types: $($v1.GetType()) and $($v2.GetType())."
		}

		if ($v1 -is [System.Collections.IDictionary]) {
			Test-Dictionary $v1 $v2
			continue
		}

		if ($v1 -cne $v2) {
			Write-Error -ErrorAction Stop "Index '$i': different values: '$v1' and '$v2'."
		}
	}
}

# Log and test the expression and expected representation
function Test-Expression($expression, $result) {
	"$expression => $result"
	$actual = (. $expression).ToString()
	if ($actual -cne $result) {
		Write-Error -ErrorAction 1 "`nExpected : $result`nActual   : $actual"
	}
}
