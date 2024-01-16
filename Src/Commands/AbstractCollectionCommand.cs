
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Bson;
using MongoDB.Driver;
using System.Management.Automation;

namespace Mdbc.Commands;

public abstract class AbstractCollectionCommand : AbstractSessionCommand
{
	IMongoCollection<BsonDocument> _Collection;

	[Parameter]
	[ValidateNotNull]
	public IMongoCollection<BsonDocument> Collection
	{
		get => _Collection ??= ResolveCollection();
		set => _Collection = value;
	}

	protected override IMongoClient MyClient => Collection.Database.Client;
}
