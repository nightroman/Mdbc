
/* Copyright 2011-2014 Roman Kuzmin
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
	public sealed class ConnectCommand : Abstract
	{
		[Parameter(Position = 0)]
		public string ConnectionString { get; set; }
		
		[Parameter(Position = 1)]
		public string DatabaseName { get; set; }
		
		[Parameter(Position = 2)]
		public string CollectionName { get; set; }
		
		[Parameter]
		[ValidateNotNull]
		public string ServerVariable { get; set; }
		
		[Parameter]
		[ValidateNotNull]
		public string DatabaseVariable { get; set; }
		
		[Parameter]
		[ValidateNotNull]
		public string CollectionVariable { get; set; }
		
		[Parameter]
		public SwitchParameter NewCollection { get; set; }
		
		protected override void BeginProcessing()
		{
			if (ConnectionString == null)
			{
				if (DatabaseName != null || CollectionName != null) throw new PSArgumentException("ConnectionString parameter is null or missing.");
				ConnectionString = ".";
				DatabaseName = "test";
				CollectionName = "test";
			}

			var client = ConnectionString == "." ? new MongoClient() : new MongoClient(ConnectionString);
			var server =  client.GetServer();
			server.Connect();
			SessionState.PSVariable.Set(ServerVariable ?? Actor.ServerVariable, server);

			if (DatabaseName == null)
				return;

			if (DatabaseName == "*")
			{
				foreach (var name in server.GetDatabaseNames())
					WriteObject(server.GetDatabase(name));
				return;
			}

			var database = server.GetDatabase(DatabaseName);
			SessionState.PSVariable.Set(DatabaseVariable ?? Actor.DatabaseVariable, database);

			if (CollectionName == null)
				return;

			if (CollectionName == "*")
			{
				foreach (var name in database.GetCollectionNames())
					WriteObject(database.GetCollection(name));
				return;
			}

			if (NewCollection)
				database.DropCollection(CollectionName);

			var collection = database.GetCollection(CollectionName);
			SessionState.PSVariable.Set(CollectionVariable ?? Actor.CollectionVariable, collection);
		}
	}
}
