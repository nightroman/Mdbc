
/* Copyright 2011 Roman Kuzmin
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
namespace Mdbc.Commands
{
	[Cmdlet(VerbsCommon.New, "MdbcData")]
	public sealed class NewDataCommand : Cmdlet
	{
		[Parameter(Position = 0, ValueFromPipeline = true)]
		public PSObject InputObject { get; set; }
		[Parameter(ValueFromPipelineByPropertyName = true)]
		public PSObject DocumentId { get; set; }
		[Parameter]
		public SwitchParameter NewDocumentId { get; set; }
		[Parameter]
		public string[] Select { get; set; }
		void WriteDocument(BsonDocument document)
		{
			if (DocumentId != null)
				document.SetDocumentId(DocumentId.BaseObject);
			else if (NewDocumentId)
				document.SetDocumentId(BsonObjectId.GenerateNewId());

			WriteObject(new Dictionary(document));
		}
		protected override void ProcessRecord()
		{
			if (InputObject == null)
			{
				WriteDocument(new BsonDocument());
				return;
			}

			if (Select != null)
			{
				WriteDocument(Actor.ToBsonDocument(InputObject, Select));
				return;
			}

			var bson = Actor.ToBsonValue(InputObject);
			switch (bson.BsonType)
			{
				case BsonType.Array:
					WriteObject(new Collection((BsonArray)bson));
					return;
				case BsonType.Document:
					WriteDocument((BsonDocument)bson);
					return;
				default:
					WriteObject(bson);
					return;
			}
		}
	}
}
