
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Driver;
using System.Management.Automation;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsCommon.Rename, "MdbcCollection")]
	public sealed class RenameCollectionCommand : AbstractDatabaseCommand
	{
		[Parameter(Position = 0, Mandatory = true)]
		public string Name { get; set; }

		[Parameter(Position = 1, Mandatory = true)]
		public string NewName { get; set; }

		[Parameter]
		public SwitchParameter Force { get; set; }

		protected override void BeginProcessing()
		{
			var options = new RenameCollectionOptions();
			if (Force)
				options.DropTarget = true;

			Database.RenameCollection(Name, NewName, options);
		}
	}
}
