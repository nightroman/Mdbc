
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Bson;
using MongoDB.Driver;
using System.Management.Automation;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsCommunications.Connect, "Mdbc")]
	public sealed class ConnectCommand : Abstract
	{
		[Parameter(Position = 0)]
		[ValidateNotNullOrEmpty]
		public string ConnectionString { get; set; }

		[Parameter(Position = 1)]
		[ValidateNotNullOrEmpty]
		public string DatabaseName { get; set; }

		[Parameter(Position = 2)]
		[ValidateNotNullOrEmpty]
		public string CollectionName { get; set; }

		[Parameter]
		[ValidateNotNullOrEmpty]
		public string ClientVariable { get; set; }

		[Parameter]
		[ValidateNotNullOrEmpty]
		public string DatabaseVariable { get; set; }

		[Parameter]
		[ValidateNotNullOrEmpty]
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
			client = (MongoClient)client.WithWriteConcern(WriteConcern.Acknowledged); //rk TODO
			SessionState.PSVariable.Set(ClientVariable ?? Actor.ClientVariable, client);

			if (DatabaseName == null)
				return;

			if (DatabaseName == "*")
			{
				foreach (var name in client.ListDatabaseNames().ToEnumerable())
					WriteObject(name);
				return;
			}

			var database = client.GetDatabase(DatabaseName);
			SessionState.PSVariable.Set(DatabaseVariable ?? Actor.DatabaseVariable, database);

			if (CollectionName == null)
				return;

			if (CollectionName == "*")
			{
				foreach (var name in database.ListCollectionNames().ToEnumerable())
					WriteObject(name);
				return;
			}

			if (NewCollection)
				database.DropCollection(CollectionName);

			var collection = database.GetCollection<BsonDocument>(CollectionName).WithWriteConcern(WriteConcern.Acknowledged); //rk TODO
			SessionState.PSVariable.Set(CollectionVariable ?? Actor.CollectionVariable, collection);
		}
	}
}
