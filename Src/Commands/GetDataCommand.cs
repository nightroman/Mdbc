
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

using System.Management.Automation;
using MongoDB.Bson;
using MongoDB.Driver;
namespace Mdbc.Commands
{
	[Cmdlet(VerbsCommon.Get, "MdbcData")]
	public sealed class GetDataCommand : AbstractCollectionCommand
	{
		[Parameter(Position = 1)]
		public PSObject Query { get; set; }
		[Parameter]
		public string[] Select { get; set; }
		[Parameter]
		public QueryFlags Modes { get; set; }
		[Parameter]
		public int Limit { get; set; }
		[Parameter]
		public int Skip { get; set; }
		[Parameter]
		public SwitchParameter Count { get; set; }
		[Parameter]
		public SwitchParameter Cursor { get; set; }
		[Parameter]
		public SwitchParameter Size { get; set; }
		protected override void BeginProcessing()
		{
			MongoCursor cursor = Query == null ? Collection.FindAllAs(typeof(BsonDocument)) : Collection.FindAs(typeof(BsonDocument), Actor.ObjectToQuery(Query));

			if (Select != null)
				cursor.SetFields(Select);

			if (Modes != QueryFlags.None)
				cursor.SetFlags(Modes);

			if (Limit > 0)
				cursor.SetLimit(Limit);

			if (Skip > 0)
				cursor.SetSkip(Skip);

			if (Count)
			{
				WriteObject(cursor.Count());
				return;
			}

			if (Size)
			{
				WriteObject(cursor.Size());
				return;
			}

			if (Cursor)
			{
				WriteObject(cursor);
				return;
			}

			foreach (BsonDocument bson in cursor)
				WriteObject(new Dictionary(bson));
		}
	}
}
