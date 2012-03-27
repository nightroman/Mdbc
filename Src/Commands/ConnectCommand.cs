
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
using MongoDB.Driver;
namespace Mdbc.Commands
{
	[Cmdlet(VerbsCommunications.Connect, "Mdbc")]
	public sealed class ConnectCommand : Cmdlet
	{
		[Parameter(Position = 0, Mandatory = true)]
		public string ConnectionString { get; set; }
		[Parameter(Position = 1)]
		public string Database { get; set; }
		[Parameter(Position = 2)]
		public string Collection { get; set; }
		[Parameter]
		public SwitchParameter NewCollection { get; set; }
		protected override void BeginProcessing()
		{
			if (ConnectionString == ".")
				ConnectionString = "mongodb://localhost";

			var server = MongoServer.Create(ConnectionString);
			server.Connect();

			if (Database == null)
			{
				WriteObject(server);
				return;
			}

			if (Database == "*")
			{
				foreach (var name in server.GetDatabaseNames())
					WriteObject(server.GetDatabase(name));
				return;
			}

			var database = server.GetDatabase(Database);

			if (Collection == null)
			{
				WriteObject(database);
				return;
			}

			if (Collection == "*")
			{
				foreach (var name in database.GetCollectionNames())
					WriteObject(database.GetCollection(name));
				return;
			}

			if (NewCollection)
				database.DropCollection(Collection);

			WriteObject(database.GetCollection(Collection));
		}
	}
}
