<#
.Synopsis
	Tests transactions and sessions.
#>

. ./Zoo.ps1

# Synopsis: How to use manual and block transactions.
task manual-and-block-transactions {
	Connect-Mdbc . test
	$Collection = Get-MdbcCollectionNew test

	$session1 = $Client.StartSession()
	try {
		$session1.StartTransaction()
		@{_id = 1} | Add-MdbcData -Session $session1
		$session1.CommitTransaction()
	}
	finally {
		$session1.Dispose()
	}

	$session1 = $Client.StartSession()
	try {
		$session1.StartTransaction()
		@{_id = 2} | Add-MdbcData -Session $session1
		$session1.AbortTransaction()
	}
	finally {
		$session1.Dispose()
	}

	Use-MdbcTransaction {
		@{_id = 3} | Add-MdbcData
	}

	Use-MdbcTransaction -ErrorAction 2 {
		@{_id = 4} | Add-MdbcData
		throw 'oops'
	}

	Get-MdbcData
}

# Synopsis: Move a document with a transaction.
task move-document {
	Connect-Mdbc . test
	$c1 = Get-MdbcCollectionNew test1
	$c2 = Get-MdbcCollectionNew test2
	@{_id = 33} | Add-MdbcData -Collection $c1

	Use-MdbcTransaction -ErrorAction 0 -ErrorVariable err {
		Get-MdbcData @{_id = 33} -Remove -Collection $c1 |
		Add-MdbcData -Collection $c2

		equals (Get-MdbcData -Count -Collection $c1) 0L
		equals "$(Get-MdbcData -Collection $c2)" '{ "_id" : 33 }'

		throw 'oops'
	}
	assert ("$err" -like "oops*At*")
	equals (Get-MdbcData -Count -Collection $c1) 1L
	equals (Get-MdbcData -Count -Collection $c2) 0L

	Use-MdbcTransaction -ErrorAction 0 -ErrorVariable err {
		Get-MdbcData @{_id = 33} -Remove -Collection $c1 |
		Add-MdbcData -Collection $c2

		equals (Get-MdbcData -Count -Collection $c1) 0L
		equals "$(Get-MdbcData -Collection $c2)" '{ "_id" : 33 }'
	}
	equals (Get-MdbcData -Count -Collection $c1) 0L
	equals "$(Get-MdbcData -Collection $c2)" '{ "_id" : 33 }'

	Remove-MdbcCollection test1
	Remove-MdbcCollection test2
}

# Synopsis: Can use another session in a block transaction.
task use-another-session-in-transaction {
	Connect-Mdbc . test

	$session1 = $Client.StartSession()
	try {
		$c1 = Get-MdbcCollectionNew test1
		$c2 = Get-MdbcCollectionNew test2
		@{_id = 33} | Add-MdbcData -Collection $c1

		Use-MdbcTransaction {
			# move the doc from one collection to another
			Get-MdbcData @{_id = 33} -Remove -Collection $c1 |
			Add-MdbcData -Collection $c2

			# test in transaction session, moved
			equals "$(Get-MdbcData -Collection $c1)" ''
			equals "$(Get-MdbcData -Collection $c2)" '{ "_id" : 33 }'

			# test in session 1, not moved
			equals "$(Get-MdbcData -Collection $c1 -Session $session1)" '{ "_id" : 33 }'
			equals "$(Get-MdbcData -Collection $c2 -Session $session1)" ''
		}
	}
	finally {
		$session1.Dispose()
	}

	Remove-MdbcCollection test1
	Remove-MdbcCollection test2
}

# Synopsis: Show not just Use-MdbcTransaction position but the actual error, too.
task show-inner-error-position {
	Connect-Mdbc .
	Use-MdbcTransaction -ErrorAction 2 -ErrorVariable err {
		throw 'oops'
	}
	assert ("$err" -like "oops*At $BuildFile*throw 'oops'*")
}

# Synopsis: Transactions are not really nested.
task nested-manual-transactions {
	Connect-Mdbc . test test

	function Test-Nested([switch]$Commit1, [switch]$Commit2) {
		$Collection = Get-MdbcCollectionNew test
		$session1 = $Client.StartSession()
		try {
			$session1.StartTransaction()
			@{_id = 1} | Add-MdbcData -Session $session1

			$session2 = $Client.StartSession()
			try {
				$session2.StartTransaction()
				@{_id = 2} | Add-MdbcData -Session $session2

				if ($Commit2) {
					$session2.CommitTransaction()
				}
			}
			finally {
				$session2.Dispose()
			}

			if ($Commit1) {
				$session1.CommitTransaction()
			}
		}
		finally {
			$session1.Dispose()
		}
	}

	Test-Nested
	equals "$(Get-MdbcData)" ''

	Test-Nested -Commit1
	equals "$(Get-MdbcData)" '{ "_id" : 1 }'

	Test-Nested -Commit2
	equals "$(Get-MdbcData)" '{ "_id" : 2 }'

	Test-Nested -Commit1 -Commit2
	equals "$(Get-MdbcData)" '{ "_id" : 1 } { "_id" : 2 }'
}

# Synopsis: Nested block transactions are allowed but they are independent.
task nested-block-transactions {
	Connect-Mdbc . test
	$Collection = Get-MdbcCollectionNew test

	# This function calls Use-MdbcTransaction with nested calls.
	function Invoke-Job1 {
		Use-MdbcTransaction {
			# add data
			@{_id = 1} | Add-MdbcData

			# call nested, provide the current session if needed
			Invoke-Job2 $Session

			#! this session cannot see nested changes
			$r = Get-MdbcData
			equals "$r" '{ "_id" : 1 }'
		}
	}

	#! Do not call the parameter "Session", Use-MdbcTransaction sets its own.
	function Invoke-Job2($ParentSession) {
		Use-MdbcTransaction {
			#! this session cannot see parent changes without -Session
			$r = Get-MdbcData
			equals "$r" ''

			# that is why, when needed, we use the session parameter
			$r = Get-MdbcData -Session $ParentSession
			equals "$r" '{ "_id" : 1 }'

			# ok, add some data
			@{_id = 2} | Add-MdbcData
		}
	}

	Invoke-Job1
	$r = Get-MdbcData
	equals "$r" '{ "_id" : 1 } { "_id" : 2 }'
}

# Synopsis: Cannot start a session transaction when another is in progress.
task start-transaction-twice {
	Connect-Mdbc .
	try {
		$session1 = $Client.StartSession()
		$session1.StartTransaction()
		$session1.StartTransaction()
		throw
	}
	catch {
		$_
		assert ("$_" -like '*Transaction already in progress.*')
	}
}

# Synopsis: Simulate a conflict of two transactions.
task conflicting-transactions {
	# init counter
	Connect-Mdbc . test test -NewCollection
	@{_id = 1; n = 1} | Add-MdbcData

	$session1 = $Client.StartSession()
	$session2 = $Client.StartSession()
	try {
		$session1.StartTransaction()
		$session2.StartTransaction()

		# inc counter in 1
		$r1 = Get-MdbcData -Session $session1 @{_id = 1} -Update @{'$inc' = @{n = 1}} -New
		equals $r1.n 2

		# inc counter in 2 -> error
		try {
			Get-MdbcData -Session $session2 @{_id = 1} -Update @{'$inc' = @{n = 1}} -New
			throw
		}
		catch {
			"$_"
			assert ("$_" -match 'WriteConflict error: this operation conflicted with another operation')
		}

		# commit 2 -> error
		try {
			$session2.CommitTransaction()
			throw
		}
		catch {
			"$_"
			assert ("$_" -match 'Command commitTransaction failed: Transaction \d+ has been aborted')
		}

		# commit 1
		$session1.CommitTransaction()
	}
	finally {
		$session2.Dispose()
		$session1.Dispose()
	}

	# inc worked once
	$r = Get-MdbcData
	equals "$r" '{ "_id" : 1, "n" : 2 }'
}

# Synopsis: Without transactions sessions see other changes.
task sessions-without-transactions {
	Connect-Mdbc -NewCollection
	$session1 = $Client.StartSession()
	$session2 = $Client.StartSession()
	try {
		@{_id = 1} | Add-MdbcData -Session $session1
		@{_id = 2} | Add-MdbcData -Session $session2

		$r = Get-MdbcData
		equals "$r" '{ "_id" : 1 } { "_id" : 2 }'

		$r = Get-MdbcData -Session $session1
		equals "$r" '{ "_id" : 1 } { "_id" : 2 }'

		$r = Get-MdbcData -Session $session2
		equals "$r" '{ "_id" : 1 } { "_id" : 2 }'
	}
	finally {
		$session2.Dispose()
		$session1.Dispose()
	}
}

# Synopsis: Script of Use-MdbcTransaction may output whatever.
task block-output {
	Connect-Mdbc . test
	$Collection = Get-MdbcCollectionNew test

	# nothing
	$r = Use-MdbcTransaction {}
	equals $r $null

	# one object
	$r = Use-MdbcTransaction {1}
	equals $r 1

	# many objects
	$r = Use-MdbcTransaction {1; 2}
	equals "$r" '1 2'

	# null on abort, even if something was written before failure
	$r = Use-MdbcTransaction -ErrorAction 0 -ErrorVariable err {1; throw 'oops'; 2}
	equals $r $null
	assert ("$err" -like "oops*throw 'oops'*")
}
