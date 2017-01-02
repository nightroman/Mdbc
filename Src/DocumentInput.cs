
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System;
using System.Collections.Generic;
using System.Management.Automation;
using MongoDB.Bson;

namespace Mdbc
{
	class DocumentInput
	{
		SessionState Session;
		ScriptBlock Convert;

		public DocumentInput()
		{ }
		public DocumentInput(SessionState session, ScriptBlock convert)
		{
			Session = session;
			Convert = convert;
		}
		// Called on exceptions. If that returns null an exception is rethrown. So for a valid null return that as BsonNull.
		public object ConvertValue(object value)
		{
			if (Convert == null)
				return null;

			using (new SetDollar(Session, value))
			{
				var result = Convert.Invoke();
				if (result.Count == 1)
				{
					var ps = result[0];
					return ps == null ? BsonNull.Value : ps.BaseObject;
				}

				return result.Count == 0 ? BsonNull.Value : null;
			}
		}
		public static BsonDocument NewDocumentWithId(bool newId, PSObject id, PSObject input, SessionState session)
		{
			if (newId && id != null) throw new PSInvalidOperationException("Parameters Id and NewId cannot be used together.");

			if (newId)
				return new BsonDocument().Add(MyValue.Id, new BsonObjectId(ObjectId.GenerateNewId()));

			if (id == null)
				return null;

			var sb = id.BaseObject as ScriptBlock;
			if (sb == null)
				return new BsonDocument().Add(MyValue.Id, BsonValue.Create(id.BaseObject));

			using (new SetDollar(session, input))
			{
				var arr = sb.Invoke();
				if (arr.Count != 1)
					throw new ArgumentException("-Id script must return a single object."); //! use this type

				return new BsonDocument().Add(MyValue.Id, BsonValue.Create(arr[0].BaseObject));
			}
		}
		public static ErrorRecord NewErrorRecordBsonValue(Exception value, object targetObject)
		{
			return new ErrorRecord(value, "BsonValue", ErrorCategory.InvalidData, targetObject);
		}
	}
}
