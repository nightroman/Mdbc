
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Driver;
using System;
using System.Diagnostics;
using System.Management.Automation;

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
		public TimeSpan Timeout { get; set; }

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
#pragma warning disable CS0618
            var server = client.GetServer();
#pragma warning restore CS0618
            if (Timeout.Ticks > 0)
			{
				// In some cases the actual time may be larger than the specified.
				// This is not just about the timeout on connection to a running server.
				// We retry as well. This is useful on waiting for a just started server.
				var sw = Stopwatch.StartNew();
				for (; ; )
				{
					try
					{
						server.Connect(Timeout);
						break;
					}
					catch(MongoConnectionException)
					{
						if (sw.Elapsed > Timeout)
							throw;
					}
				}
			}
			else
			{
				server.Connect();
			}
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
