
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
	[Cmdlet(VerbsData.Update, "MdbcData")]
	public sealed class UpdateDataCommand : AbstractWriteCommand
	{
		[Parameter(Position = 0, Mandatory = true)]
		public object Update { get { return null; } set { _Update = Actor.ObjectToUpdate(value); } }
		IMongoUpdate _Update;

		[Parameter(Position = 1, Mandatory = true, ValueFromPipeline = true)]
		public object Query { get { return null; } set { _Input = value; _Query = Actor.ObjectToQuery(value); } }
		IMongoQuery _Query;
		object _Input;

		[Parameter]
		public UpdateFlags Modes { get; set; }

		protected override void ProcessRecord()
		{
			try
			{
				WriteResult(Collection.Update(_Query, _Update, Modes, WriteConcern));
			}
			catch (MongoException ex)
			{
				WriteException(ex, _Input);
			}
		}
	}
}
