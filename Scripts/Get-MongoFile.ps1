
<#
.Synopsis
	Gets files from the file system snapshot database.

.Description
	Requires: Mdbc module
	Server: local
	Database: test
	Collection: files

	The script searches for file paths by a name or a regular expression
	pattern. It works with data created by Update-MongoFiles.ps1.

LICENSE

	* Mdbc module - MongoDB Windows PowerShell Cmdlets
	* Copyright (c) 2011 Roman Kuzmin
	*
	* Licensed under the Apache License, Version 2.0 (the "License");
	* you may not use this file except in compliance with the License.
	* You may obtain a copy of the License at
	*
	* http://www.apache.org/licenses/LICENSE-2.0
	*
	* Unless required by applicable law or agreed to in writing, software
	* distributed under the License is distributed on an "AS IS" BASIS,
	* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	* See the License for the specific language governing permissions and
	* limitations under the License.

.Parameter Name
	A file name or a regular expression to search for. The search is case
	insensitive.

.Parameter Match
	Tells that the Name is a regular expression pattern.

.Example
	> Get-MongoFile readme.txt
	Get files named "readme.txt"

.Example
	> Get-MongoFile -Match readme
	Get files which names contain "readme".

.Link
	Update-MongoFiles.ps1
#>

param
(
	[Parameter(Mandatory = $true)]
	$Name
	,
	[Parameter()]
	[switch]$Match
)

Import-Module Mdbc
$collection = Connect-Mdbc . test files

if ($Match) {
	$query = query Name -Match $Name, 'i'
}
else {
	$query = query Name -IEQ $Name
}

Get-MdbcData $collection $query -Select @() | .{process{ $_._id }}
