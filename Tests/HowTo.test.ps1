
<#
.Synopsis
	Covers some how-to cases.
#>

Import-Module Mdbc

# Synopsis: Create unique index. #15
task CreateUniqueIndex {
	Connect-Mdbc -NewCollection

	$keys = (New-Object MongoDB.Driver.Builders.IndexKeysBuilder).Ascending('tax-id')
	$options = (New-Object MongoDB.Driver.Builders.IndexOptionsBuilder).SetName('tax-id').SetUnique($true)
	$null = $Collection.CreateIndex($keys, $options)

	$r = $Collection.GetIndexes()
	$r | Out-String

	equals $r.Count 2
	equals $r[0].Name _id_
	equals $r[0].IsUnique $false
	equals $r[1].Name tax-id
	equals $r[1].IsUnique $true
}
