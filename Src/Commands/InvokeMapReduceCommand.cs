
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System.Collections;
using System.Management.Automation;
using MongoDB.Bson;
using MongoDB.Driver;
using MongoDB.Driver.Builders;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsLifecycle.Invoke, "MdbcMapReduce")]
	public sealed class InvokeMapReduceCommand : AbstractCollectionCommand
	{
		[Parameter(Position = 0, Mandatory = true)]
		[ValidateCount(2, 3)]
		public string[] Function { get; set; }

		[Parameter(Position = 1)]
		public object Query { get { return null; } set { _Query = Actor.ObjectToQuery(value); } }
		IMongoQuery _Query;

		[Parameter]
		public object[] SortBy { get { return null; } set { _SortBy = Actor.ObjectsToSortBy(value); } }
		IMongoSortBy _SortBy;

		[Parameter]
		public int First { get; set; }

		[Parameter]
		public IDictionary Scope { get; set; }

		[Parameter]
		public SwitchParameter JSMode { get; set; }

		[Parameter]
		public string ResultVariable { get; set; }

		[Parameter]
		public MapReduceOutputMode OutMode { get; set; }

		[Parameter]
		public string OutDatabase { get; set; }

		[Parameter]
		public string OutCollection { get; set; }

		[Parameter]
		public PSObject As { get { return null; } set { _ParameterAs = new ParameterAs(value); } }
		ParameterAs _ParameterAs;

		protected override void BeginProcessing()
		{
			var mc = TargetCollection.Collection as MongoCollection;
			if (mc == null) ThrowNotImplementedForFiles("MapReduce");

			var args = new MapReduceArgs();

			args.JsMode = JSMode;

			args.MapFunction = new BsonJavaScript(Function[0]);
			args.ReduceFunction = new BsonJavaScript(Function[1]);
			if (Function.Length == 3)
				args.FinalizeFunction = new BsonJavaScript(Function[2]);

			if (_Query != null)
				args.Query = _Query;

			if (_SortBy != null)
				args.SortBy = _SortBy;

			if (First > 0)
				args.Limit = First;

			if (Scope != null)
				args.Scope = new ScopeDocument(Scope);

			if (!string.IsNullOrEmpty(OutCollection) && OutMode == MapReduceOutputMode.Inline)
				OutMode = MapReduceOutputMode.Replace;

			// output
			args.OutputMode = OutMode;
			args.OutputDatabaseName = OutDatabase;
			args.OutputCollectionName = OutCollection;

			var result = mc.MapReduce(args);

			if (ResultVariable != null)
				SessionState.PSVariable.Set(ResultVariable, result);

			if (OutMode != MapReduceOutputMode.Inline)
				return;

			var documentAs = _ParameterAs ?? new ParameterAs(null);

			//_131018_160000
			foreach (var it in result.GetInlineResultsAs(documentAs.Type))
				WriteObject(it);
		}
	}
}
