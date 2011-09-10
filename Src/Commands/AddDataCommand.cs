
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
using MongoDB.Driver;
namespace Mdbc.Commands
{
	[Cmdlet(VerbsCommon.Add, "MdbcData")]
	public sealed class AddDataCommand : AbstractCollectionCommand
	{
		[Parameter(Position = 1, ValueFromPipeline = true)]
		public PSObject InputObject { get; set; }
		[Parameter]
		public SafeMode SafeMode { get; set; }
		[Parameter]
		public SwitchParameter Safe { get; set; }
		[Parameter]
		public SwitchParameter Update { get; set; }
		protected override void ProcessRecord()
		{
			if (InputObject == null)
				return;

			var bson = Actor.ToBsonDocument(InputObject, null);

			if (Safe)
				SafeMode = new SafeMode(Safe);

			SafeModeResult result;
			if (Update)
				result = SafeMode == null ? Collection.Save(bson) : Collection.Save(bson, SafeMode);
			else
				result = SafeMode == null ? Collection.Insert(bson) : Collection.Insert(bson, SafeMode);

			if (result != null)
				WriteObject(result);
		}
	}
}
