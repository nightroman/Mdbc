
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
		[Parameter(Position = 0, Mandatory = true, ValueFromPipeline = true)]
		public object Query { get { return null; } set { _Query = Actor.ObjectToQuery(value); } }
		IMongoQuery _Query;

		[Parameter]
		public RemoveFlags Modes { get; set; }

		protected override void ProcessRecord()
		{
			try
			{
				if (FileCollection == null)
				{
					WriteResult(MongoCollection.Remove(_Query, Modes, WriteConcern));
				}
				else
				{
					if (Result) ThrowNotImplementedForFiles("Parameter Result"); //TODO
					FileCollection.Remove(_Query, Modes);
				}
			}
			catch (MongoException ex)
			{
				WriteException(ex, null);
			}
		}
	}
}
