
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System;
using System.Collections.Generic;
using System.Management.Automation;
using MongoDB.Bson;

namespace Mdbc
{
	static class DocumentInput
	{
		public static object ConvertValue(ScriptBlock convert, object value)
		{
			var result = Actor.InvokeWithDollar(convert, value);
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
		public static BsonDocument NewDocumentWithId(bool newId, PSObject id, PSObject input)
		{
			if (newId && id != null) throw new PSInvalidOperationException("Parameters Id and NewId cannot be used together.");

			if (newId)
				return new BsonDocument().Add(MyValue.Id, new BsonObjectId(ObjectId.GenerateNewId()));

			if (id == null)
				return null;

			if (!(id.BaseObject is ScriptBlock sb))
				return new BsonDocument().Add(MyValue.Id, BsonValue.Create(id.BaseObject));

			var arr = Actor.InvokeWithDollar(sb, input);
			if (arr.Count != 1)
				throw new ArgumentException("-Id script must return a single object."); //! use this type
			return new BsonDocument().Add(MyValue.Id, BsonValue.Create(arr[0].BaseObject));
		}
		public static ErrorRecord NewErrorRecordBsonValue(Exception value, object targetObject)
		{
			return new ErrorRecord(value, "BsonValue", ErrorCategory.InvalidData, targetObject);
		}
	}
}
