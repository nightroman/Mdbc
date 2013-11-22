
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
using MongoDB.Driver;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsCommon.Remove, "MdbcData")]
	public sealed class RemoveDataCommand : AbstractWriteCommand
	{
		//_131121_104038 Not mandatory to avoid prompts. Manual null check is used instead for consistent messages.
		// String values from prompts might imply unexpected results.
		[Parameter(Position = 0, ValueFromPipeline = true)]
		public object Query { get { return null; } set { _Query = Actor.ObjectToQuery(value); } }
		IMongoQuery _Query;

		//_131122_164305
		[Parameter]
		public SwitchParameter One { get; set; }

		RemoveFlags _Flags;

		protected override void BeginProcessing()
		{
			if (One)
				_Flags |= RemoveFlags.Single;
		}
		protected override void ProcessRecord()
		{
			if (_Query == null) throw new PSArgumentException(TextParameterQuery); //_131121_104038
			
			try
			{
				WriteResult(TargetCollection.Remove(_Query, _Flags, WriteConcern, Result));
			}
			catch (MongoException ex)
			{
				WriteException(ex, null);
			}
		}
	}
}
