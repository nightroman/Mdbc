
using MongoDB.Bson;
using MongoDB.Driver;
using System.Management.Automation;

namespace Mdbc.Commands;

[Cmdlet(VerbsCommon.Watch, "MdbcChange"), OutputType(typeof(IAsyncCursor<object>))]
public sealed class WatchChangeCommand : AbstractSessionCommand
{
	[Parameter(Position = 0)]
	public object Pipeline { set { if (value != null) _Pipeline = Api.PipelineDefinition<ChangeStreamDocument<BsonDocument>, BsonDocument>(value); } }
	PipelineDefinition<ChangeStreamDocument<BsonDocument>, BsonDocument> _Pipeline;

	[Parameter(Mandatory = true, ParameterSetName = "Collection")]
	public IMongoCollection<BsonDocument> Collection { get; set; }

	[Parameter(Mandatory = true, ParameterSetName = "Database")]
	public IMongoDatabase Database { get; set; }

	[Parameter(Mandatory = true, ParameterSetName = "Client")]
	public IMongoClient Client { get; set; }

	[Parameter]
	public ChangeStreamOptions Options { get; set; }

	[Parameter]
	public object As { set { _As.Set(value); } }
	readonly ParameterAs _As = new();

	protected override IMongoClient MyClient
	{
		get
		{
			if (Collection != null)
				return Collection.Database.Client;
			else if (Database != null)
				return Database.Client;
			else
				return Client;
		}
	}

	protected override void BeginProcessing()
	{
		_Pipeline ??= new List<BsonDocument>();

		IChangeStreamCursor<BsonDocument> cursor;
		if (Collection != null)
			cursor = Collection.Watch(Session, _Pipeline, Options);
		else if (Database != null)
			cursor = Database.Watch(Session, _Pipeline, Options);
		else
			cursor = Client.Watch(Session, _Pipeline, Options);

		WriteObject(new ChangeStreamCursor(cursor, _As.Type));
	}
}

sealed class ChangeStreamCursor : IDisposable, IAsyncCursor<object>
{
	readonly IChangeStreamCursor<BsonDocument> _cursor;
	readonly Func<BsonDocument, object> _convert;
	internal ChangeStreamCursor(IChangeStreamCursor<BsonDocument> cursor, Type outputType)
	{
		_cursor = cursor;
		_convert = Actor.ConvertDocument(outputType);
	}
	public void Dispose()
	{
		_cursor.Dispose();
	}
	public IEnumerable<object> Current
	{
		get
		{
			return _cursor.Current.Select(_convert);
		}
	}
	public bool MoveNext(CancellationToken cancellationToken = default)
	{
		return _cursor.MoveNext(cancellationToken);
	}
	public Task<bool> MoveNextAsync(CancellationToken cancellationToken = default)
	{
		return _cursor.MoveNextAsync(cancellationToken);
	}
}
