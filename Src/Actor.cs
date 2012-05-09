
/* Copyright 2011-2012 Roman Kuzmin
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
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;
using MongoDB.Bson;
using MongoDB.Driver;
using MongoDB.Driver.Builders;
namespace Mdbc
{
	static class Actor
	{
		public static object ToObject(BsonValue value) //_120509_173140 keep consistent
		{
			if (value == null)
				return null;

			switch (value.BsonType)
			{
				case BsonType.Array: return new Collection((BsonArray)value); // wrapper
				case BsonType.Binary: return value.RawValue ?? value; // byte[] or Guid else self
				case BsonType.Boolean: return value.RawValue;
				case BsonType.DateTime: return ((BsonDateTime)value).Value;
				case BsonType.Document: return new Dictionary((BsonDocument)value); // wrapper
				case BsonType.Double: return ((BsonDouble)value).Value;
				case BsonType.Int32: return ((BsonInt32)value).Value;
				case BsonType.Int64: return ((BsonInt64)value).Value;
				case BsonType.Null: return null;
				case BsonType.String: return ((BsonString)value).Value;
				default: return value;
			}
		}
		public static BsonValue ToBsonValue(object value)
		{
			if (value == null)
				return BsonNull.Value;

			var ps = value as PSObject;
			if (ps != null)
				value = ps.BaseObject;

			var bson = value as BsonValue;
			if (bson != null)
				return bson;

			var text = value as string;
			if (text != null)
				return new BsonString(text);

			if (value is PSCustomObject && ps != null)
				return ToBsonDocument(ps, null);

			var script = value as ScriptBlock;
			if (script != null)
				return ScriptToBsonDocument(script);

			var enumerable = value as IEnumerable;
			if (enumerable == null)
				return BsonValue.Create(value);

			var dictionary = value as IDictionary;
			if (dictionary == null)
			{
				var array = new BsonArray();
				foreach (var it in enumerable)
					array.Add(ToBsonValue(it));
				return array;
			}

			var mongo = value as Dictionary;
			if (mongo != null)
				return mongo.Document();

			return ToBsonDocument(value, null);
		}
		public static BsonDocument ToBsonDocument(object value, IEnumerable properties)
		{
			var ps = value as PSObject;
			if (ps != null)
				value = ps.BaseObject;

			var mongo = value as Dictionary;
			if (mongo != null)
				return mongo.Document();

			var document = value as BsonDocument;
			if (document != null)
				return document;

			var dictionary = value as IDictionary;
			if (dictionary != null)
			{
				if (properties == null)
					properties = dictionary.Keys;

				document = new BsonDocument();
				foreach (var key in properties)
					document.Add(key.ToString(), ToBsonValue(dictionary[key]));

				return document;
			}

			if (properties == null)
			{
				document = new BsonDocument();
				foreach (var pi in (ps ?? PSObject.AsPSObject(value)).Properties)
				{
					try
					{
						var data = pi.Value;
						if (data != null)
							document.Add(pi.Name, ToBsonValue(data));
					}
					catch (Exception) //???
					{
					}
				}
				return document;
			}

			document = new BsonDocument();
			ps = ps ?? PSObject.AsPSObject(value);
			foreach (var name in properties)
			{
				try
				{
					var pi = ps.Properties[name.ToString()];
					var data = pi.Value;
					if (data != null)
						document.Add(pi.Name, ToBsonValue(data));
				}
				catch (Exception) //???
				{
				}
			}
			return document;
		}
		public static IEnumerable<BsonValue> ToBsonValues(object value)
		{
			var bsonValue = ToBsonValue(value);

			var bsonArray = bsonValue as BsonArray;
			if (bsonArray != null)
				return bsonArray;

			return new[] { bsonValue };
		}
		public static BsonDocument ScriptToBsonDocument(ScriptBlock script)
		{
			var document = new BsonDocument();
			foreach (var ps in script.Invoke())
			{
				var element = ps.BaseObject as BsonElement;
				if (element == null)
					throw new PSInvalidCastException("Invalid type: " + ps.BaseObject.GetType().Name);

				document.Add(element.Name, element.Value);
			}
			return document;
		}
		public static IMongoQuery DocumentIdToQuery(BsonDocument document)
		{
			return Query.EQ("_id", document["_id"]);
		}
		public static IMongoQuery ObjectToQuery(object value)
		{
			if (value == null)
				return Query.Null;

			var ps = value as PSObject;
			if (ps != null)
				value = ps.BaseObject;

			var query = value as IMongoQuery;
			if (query != null)
				return query;

			var mdbc = value as Dictionary;
			if (mdbc != null)
				return DocumentIdToQuery(mdbc.Document());

			var bson = value as BsonDocument;
			if (bson != null)
				return DocumentIdToQuery(bson);

			var dictionary = value as IDictionary;
			if (dictionary != null)
				return new QueryDocument(dictionary);

			return Query.EQ("_id", BsonValue.Create(value));
		}
		/// <summary>
		/// Safe cast from Object or PSObject.
		/// </summary>
		public static T Cast<T>(object obj) where T : class
		{
			if (obj == null)
				return null;

			var pso = obj as PSObject;
			if (pso != null)
				return pso.BaseObject as T;

			return obj as T;
		}
		/// <summary>
		/// Converts PS objects to a SortBy object.
		/// </summary>
		/// <param name="values">Strings or @{Name=Boolean}. Null and empty is allowed.</param>
		/// <returns>SortBy object, may be empty but not null.</returns>
		public static IMongoSortBy ObjectsToSortBy(IEnumerable values)
		{
			if (values == null)
				return SortBy.Null;
			
			var builder = new SortByBuilder();
			foreach (var it in values)
			{
				var name = it as string;
				if (name != null)
				{
					builder.Ascending(name);
					continue;
				}

				var hash = it as IDictionary;
				if (hash == null) throw new ArgumentException("SortBy: Invalid value type.");
				if (hash.Count != 1) throw new ArgumentException("SortBy: Expected a dictionary with one entry.");

				foreach (DictionaryEntry kv in hash)
				{
					name = kv.Key.ToString();
					if (LanguagePrimitives.IsTrue(kv.Value))
						builder.Ascending(name);
					else
						builder.Descending(name);
				}
			}
			return builder;
		}
		public static IMongoUpdate ObjectToUpdate(PSObject value)
		{
			var update = value.BaseObject as IMongoUpdate;
			if (update != null)
				return update;

			var dictionary = value.BaseObject as IDictionary;
			if (dictionary != null)
				return new UpdateDocument(Actor.ToBsonDocument(dictionary, null));

			var enumerable = LanguagePrimitives.GetEnumerable(value.BaseObject);
			if (enumerable != null)
				return Update.Combine(enumerable.Cast<object>().Select(Actor.Cast<UpdateBuilder>));

			throw new PSInvalidCastException("Invalid update type. Valid types: update, dictionary.");
		}
	}
}
