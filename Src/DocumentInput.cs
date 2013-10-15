
/* Copyright 2011-2013 Roman Kuzmin
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

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
		// Called on exceptions. If it returns null an exception is rethrown. So for a valid null return it as BsonNull.
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
				return new BsonDocument().Add("_id", new BsonObjectId(ObjectId.GenerateNewId()));

			if (id == null)
				return null;

			var sb = id.BaseObject as ScriptBlock;
			if (sb == null)
				return new BsonDocument().Add("_id", BsonValue.Create(id.BaseObject));

			using (new SetDollar(session, input))
			{
				var arr = sb.Invoke();
				if (arr.Count != 1)
					throw new ArgumentException("-Id script must return a single object."); //! use this type

				return new BsonDocument().Add("_id", BsonValue.Create(arr[0].BaseObject));
			}
		}
		public static ErrorRecord NewErrorRecordBsonValue(Exception value, object targetObject)
		{
			return new ErrorRecord(value, "BsonValue", ErrorCategory.InvalidData, targetObject);
		}
	}
}
