
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

using System;
using System.IO;
using System.Management.Automation;
using MongoDB.Bson;
using MongoDB.Bson.IO;
using MongoDB.Bson.Serialization;
namespace Mdbc.Commands
{
	[Cmdlet(VerbsData.Import, "MdbcData")]
	public sealed class ImportDataCommand : PSCmdlet
	{
		[Parameter(Position = 0, Mandatory = true)]
		public string Path { get; set; }
		[Parameter]
		public Type As { get; set; }
		[Parameter]
		public SwitchParameter AsCustomObject { get; set; }
		protected override void BeginProcessing()
		{
			Type documentType = AsCustomObject ? typeof(PSObject) : As ?? typeof(BsonDocument);
			bool isBsonDocument = documentType == typeof(BsonDocument);
			if (documentType == typeof(PSObject))
				PSObjectSerializer.Register();

			Path = GetUnresolvedProviderPathFromPSPath(Path);
			using (var stream = File.OpenRead(Path))
			{
				long length = stream.Length;
				
				while (stream.Position < length)
				{
					using (var _reader = BsonReader.Create(stream))
					{
						var document = BsonSerializer.Deserialize(_reader, documentType);
						if (isBsonDocument)
							WriteObject(new Dictionary((BsonDocument)document));
						else
							WriteObject(document);
					}
				}
			}
		}
	}
}
