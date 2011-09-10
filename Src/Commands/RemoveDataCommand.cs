
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
	[Cmdlet(VerbsCommon.Remove, "MdbcData")]
	public sealed class RemoveDataCommand : AbstractCollectionCommand
	{
		[Parameter(Position = 1, Mandatory = true)]
		public IMongoQuery Query { get; set; }
		[Parameter]
		public RemoveFlags Modes { get; set; }
		[Parameter]
		public SafeMode SafeMode { get; set; }
		[Parameter]
		public SwitchParameter Safe { get; set; }
		protected override void ProcessRecord()
		{
			if (Safe)
				SafeMode = new SafeMode(Safe);

			SafeModeResult result = SafeMode == null ? Collection.Remove(Query, Modes) : Collection.Remove(Query, Modes, SafeMode);

			if (result != null)
				WriteObject(result);
		}
	}
}
