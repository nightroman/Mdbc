﻿
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System.Management.Automation;

namespace Mdbc.Commands;

[Cmdlet(VerbsCommon.Remove, "MdbcCollection")]
public sealed class RemoveCollectionCommand : AbstractDatabaseCommand
{
	[Parameter(Position = 0, Mandatory = true)]
	public string Name { get; set; }

	protected override void BeginProcessing()
	{
		Database.DropCollection(Name);
	}
}
