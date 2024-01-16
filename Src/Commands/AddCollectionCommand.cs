
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System.Management.Automation;
using MongoDB.Driver;

namespace Mdbc.Commands;

[Cmdlet(VerbsCommon.Add, "MdbcCollection")]
public sealed class AddCollectionCommand : AbstractDatabaseCommand
{
	[Parameter(Position = 0, Mandatory = true)]
	public string Name { get; set; }

	[Parameter]
	public CreateCollectionOptions Options { get; set; }

	protected override void BeginProcessing()
	{
		Database.CreateCollection(Name, Options);
	}
}
