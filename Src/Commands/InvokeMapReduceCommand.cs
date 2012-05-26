
/* Copyright 2011-2012 Roman Kuzmin
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
*/

using System;
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
		public Type As { get; set; }
		[Parameter]
		public SwitchParameter AsCustomObject { get; set; }
		Type GetDocumentType()
		{
			return AsCustomObject ? typeof(PSObject) : As ?? typeof(BsonDocument);
		}
		protected override void BeginProcessing()
		{
			var options = new MapReduceOptionsBuilder();

			options.SetJSMode(JSMode);

			if (Function.Length == 3)
				options.SetFinalize(new BsonJavaScript(Function[2]));

			if (_Query != null)
				options.SetQuery(_Query);

			if (_SortBy != null)
				options.SetSortOrder(_SortBy);

			if (First > 0)
				options.SetLimit(First);

			if (Scope != null)
				options.SetScope(new ScopeDocument(Scope));

			if (!string.IsNullOrEmpty(OutCollection) && OutMode == MapReduceOutputMode.Inline)
				OutMode = MapReduceOutputMode.Replace;

			var output = new MapReduceOutput();
			output.Mode = OutMode;
			output.DatabaseName = OutDatabase;
			output.CollectionName = OutCollection;
			options.SetOutput(output);

			var result = Collection.MapReduce(new BsonJavaScript(Function[0]), new BsonJavaScript(Function[1]), options);
			
			if (ResultVariable != null)
				SessionState.PSVariable.Set(ResultVariable, result);

			if (OutMode != MapReduceOutputMode.Inline)
				return;

			var documentType = GetDocumentType();
			var documents = result.GetInlineResultsAs(documentType);
			if (documentType == typeof(BsonDocument))
			{
				foreach (BsonDocument bson in documents)
					WriteObject(new Dictionary(bson));
			}
			else
			{
				if (documentType == typeof(PSObject))
					PSObjectSerializer.Register();

				WriteObject(documents, true);
			}
		}
	}
}
