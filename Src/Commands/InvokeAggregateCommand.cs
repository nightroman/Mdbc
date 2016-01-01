
// Copyright (c) 2011-2016 Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System;
using System.Collections.Generic;
using System.Management.Automation;
using MongoDB.Bson;
using MongoDB.Driver;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsLifecycle.Invoke, "MdbcAggregate")]
	public sealed class InvokeAggregateCommand : AbstractCollectionCommand
	{
		[Parameter(Position = 0, Mandatory = true)]
		public object Pipeline { get { return null; } set { _Pipeline = Actor.ObjectToBsonDocuments(value); } }
		IEnumerable<BsonDocument> _Pipeline;

		[Parameter]
		public int BatchSize { get; set; }

		[Parameter]
		public TimeSpan MaxTime { get; set; }

		[Parameter]
		public SwitchParameter AllowDiskUse { get; set; }

		//[Parameter]
		//public SwitchParameter Explain { get; set; }

		protected override void BeginProcessing()
		{
			var mc = TargetCollection.Collection as MongoCollection;
			if (mc == null) ThrowNotImplementedForFiles("Aggregate");

			var args = new AggregateArgs() { Pipeline = _Pipeline, OutputMode = AggregateOutputMode.Cursor };
			if (AllowDiskUse)
				args.AllowDiskUse = true;
			if (BatchSize > 0)
				args.BatchSize = BatchSize;
			if (MaxTime.Ticks > 0)
				args.MaxTime = MaxTime;

			//if (Explain)
			//{
			//    WriteObject(new Dictionary(mc.AggregateExplain(args).Response));
			//    return;
			//}

			var result = mc.Aggregate(args);
			foreach (var document in result)
				WriteObject(new Dictionary(document));
		}
	}
}
