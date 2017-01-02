
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System.Management.Automation;
using MongoDB.Driver.Builders;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsCommon.Add, "MdbcCollection")]
	public sealed class AddCollectionCommand : AbstractDatabaseCommand
	{
		[Parameter(Position = 0, Mandatory = true)]
		public string Name { get; set; }

		[Parameter]
		public long MaxSize { get; set; }

		[Parameter]
		public long MaxDocuments { get; set; }

		[Parameter]
		public bool AutoIndexId { get { return AutoIndexId; } set { _setAutoIndexId = true; _AutoIndexId = value; } }
		bool _setAutoIndexId;
		bool _AutoIndexId;

		protected override void BeginProcessing()
		{
			// default options
			var options = new CollectionOptionsBuilder();

			// capped collection
			if (MaxSize > 0)
			{
				options.SetCapped(true);
				options.SetMaxSize(MaxSize);
				if (MaxDocuments > 0)
					options.SetMaxDocuments(MaxDocuments);
			}

			// auto arrayIndex explicitly, otherwise default is used
			if (_setAutoIndexId)
				options.SetAutoIndexId(_AutoIndexId);

			Database.CreateCollection(Name, options);
		}
	}
}
