
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Bson;
using System;
using System.Collections.Generic;

namespace Mdbc;

static class ClassMap
{
	static readonly HashSet<Type> _types = [];

	internal static void Add(Type type)
	{
		_types.Add(type);
	}

	internal static bool Contains(Type type)
	{
		return _types.Contains(type);
	}
}

//_131102_084424 Unwraps PSObject's like Get-Date.
class PSObjectTypeMapper : ICustomBsonTypeMapper
{
	public bool TryMapToBsonValue(object value, out BsonValue bsonValue)
	{
		bsonValue = Actor.ToBsonValue(value);
		return true;
	}
}

class GuidTypeMapper : ICustomBsonTypeMapper
{
	public bool TryMapToBsonValue(object value, out BsonValue bsonValue)
	{
		if (value is Guid guid)
		{
			bsonValue = new BsonBinaryData(guid, Api.GuidRepresentation);
			return true;
		}
		else
		{
			bsonValue = null;
			return false;
		}
	}
}

static class BsonId
{
	public const string Name = "_id";

	public static BsonElement Element(BsonValue value)
	{
		return new BsonElement(Name, value);
	}
}
