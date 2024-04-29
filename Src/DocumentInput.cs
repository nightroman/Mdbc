
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Bson;
using System;
using System.Management.Automation;

namespace Mdbc;

static class DocumentInput
{
	public static object ConvertValue(ScriptBlock convert, object value)
	{
		var result = PS2.InvokeWithContext(convert, value);
		switch (result.Count)
		{
			case 0:
				return null;
			case 1:
				{
					var ps = result[0];
					return ps?.BaseObject;
				}
			default:
				//! use this type
				throw new RuntimeException($"Converter script should return one value or none but it returns {result.Count}.");
		}
	}

	public static BsonDocument NewDocumentWithId(bool newId, object id, object input)
	{
		if (newId && id != null)
			throw new PSInvalidOperationException("Parameters Id and NewId cannot be used together.");

		if (newId)
			return new BsonDocument(BsonId.Element(new BsonObjectId(ObjectId.GenerateNewId())));

		if (id == null)
			return null;

		id = id.ToBaseObject();
		if (id is not ScriptBlock sb)
			return new BsonDocument(BsonId.Element(BsonValue.Create(id)));

		var arr = PS2.InvokeWithContext(sb, input);
		if (arr.Count != 1)
			throw new ArgumentException("-Id script must return a single object."); //! use this type

		return new BsonDocument(BsonId.Element(BsonValue.Create(arr[0].BaseObject)));
	}

	public static ErrorRecord NewErrorRecordBsonValue(Exception value, object targetObject)
	{
		return new ErrorRecord(value, "BsonValue", ErrorCategory.InvalidData, targetObject);
	}
}
