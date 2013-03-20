
/* Copyright 2011-2013 Roman Kuzmin
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
		public PSObject Id { get; set; }
		[Parameter]
		public SwitchParameter NewId { get; set; }
		[Parameter]
		public string[] Property { get; set; }
		void WriteDocument(BsonDocument document)
		{
			if (Id != null)
				document["_id"] = BsonValue.Create(Id.BaseObject);
			else if (NewId)
				document["_id"] = new BsonObjectId(ObjectId.GenerateNewId());

			WriteObject(new Dictionary(document));
		}
		protected override void ProcessRecord()
		{
			if (InputObject == null)
			{
				WriteDocument(new BsonDocument());
				return;
			}

			if (Property != null)
			{
				WriteDocument(Actor.ToBsonDocument(InputObject, Property));
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
