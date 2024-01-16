
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Bson;
using MongoDB.Driver;
using System;
using System.Management.Automation;

namespace Mdbc.Commands;

/// <summary>
/// Common base class for all Mdbc commands.
/// </summary>
public abstract class Abstract : PSCmdlet
{
	protected void WriteException(Exception exception, object target)
	{
		WriteError(new ErrorRecord(exception, "Mdbc", ErrorCategory.NotSpecified, target));
	}
	protected MongoClient ResolveClient()
	{
		if (PS2.BaseObject(GetVariableValue(Actor.ClientVariable)) is MongoClient client)
			return client;

		throw new PSInvalidOperationException("Specify a client by the parameter or variable Client.");
	}
	protected IMongoDatabase ResolveDatabase()
	{
		if (PS2.BaseObject(GetVariableValue(Actor.DatabaseVariable)) is IMongoDatabase database)
			return database;

		throw new PSInvalidOperationException("Specify a database by the parameter or variable Database.");
	}
	protected IMongoCollection<BsonDocument> ResolveCollection()
	{
		if (PS2.BaseObject(GetVariableValue(Actor.CollectionVariable)) is IMongoCollection<BsonDocument> collection)
			return collection;

		throw new PSInvalidOperationException("Specify a collection by the parameter or variable Collection.");
	}
}
