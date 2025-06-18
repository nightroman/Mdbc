
using MongoDB.Bson;
using MongoDB.Driver;
using System.Management.Automation;

namespace Mdbc.Commands;

[Cmdlet(VerbsCommunications.Connect, "Mdbc", DefaultParameterSetName = "ConnectionString")]
public sealed class ConnectCommand : Abstract
{
	const string
		nsConnectionString = "ConnectionString",
		nsSettings = "Settings",
		nsUrl = "Url";

	[Parameter(Position = 0, ParameterSetName = nsConnectionString)]
	[ValidateNotNullOrEmpty]
	public string ConnectionString { get; set; }

	[Parameter(Position = 0, ParameterSetName = nsSettings)]
	[ValidateNotNull]
	public MongoClientSettings Settings { get; set; }

	[Parameter(Position = 0, ParameterSetName = nsUrl)]
	[ValidateNotNull]
	public MongoUrl Url { get; set; }

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
		MongoClient client;
		switch (ParameterSetName)
		{
			case nsConnectionString:
				{
					if (ConnectionString == null)
					{
						if (DatabaseName != null || CollectionName != null) throw new PSArgumentException("ConnectionString parameter is null or missing.");
						ConnectionString = ".";
						DatabaseName = "test";
						CollectionName = "test";
					}

					client = ConnectionString == "." ? new MongoClient() : new MongoClient(ConnectionString);
					break;
				}
			case nsSettings:
				{
					client = new MongoClient(Settings);
					break;
				}
			case nsUrl:
				{
					client = new MongoClient(Url);
					break;
				}
			default:
				return;
		}

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

		var collection = database.GetCollection<BsonDocument>(CollectionName);
		SessionState.PSVariable.Set(CollectionVariable ?? Actor.CollectionVariable, collection);
	}
}
