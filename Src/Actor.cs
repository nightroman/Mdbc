
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
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Management.Automation;
using MongoDB.Bson;
using MongoDB.Driver;
using MongoDB.Driver.Builders;

namespace Mdbc
{
	static class Actor
	{
		internal const string ServerVariable = "Server";
		internal const string DatabaseVariable = "Database";
		internal const string CollectionVariable = "Collection";
		public static object ToObject(BsonValue value) //_120509_173140 keep consistent
		{
			if (value == null)
				return null;

			switch (value.BsonType)
			{
				case BsonType.Array: return new Collection((BsonArray)value); // wrapper
				case BsonType.Binary: return BsonTypeMapper.MapToDotNetValue(value) ?? value; // byte[] or Guid else self
				case BsonType.Boolean: return ((BsonBoolean)value).Value;
				case BsonType.DateTime: return ((BsonDateTime)value).ToUniversalTime();
				case BsonType.Document: return new Dictionary((BsonDocument)value); // wrapper
				case BsonType.Double: return ((BsonDouble)value).Value;
				case BsonType.Int32: return ((BsonInt32)value).Value;
				case BsonType.Int64: return ((BsonInt64)value).Value;
				case BsonType.Null: return null;
				case BsonType.ObjectId: return ((BsonObjectId)value).Value;
				case BsonType.String: return ((BsonString)value).Value;
				default: return value;
			}
		}
		public static BsonValue ToBsonValue(object value)
		{
			return ToBsonValue(value, null, null);
		}
		static BsonValue ToBsonValue(object value, DocumentInput input, ArrayList cycle)
		{
			if (value == null)
				return BsonNull.Value;

			var ps = value as PSObject;
			if (ps != null)
			{
				value = ps.BaseObject;

				// case: custom
				if (value is PSCustomObject) //! PSObject keeps properties
					return ToBsonDocumentFromProperties(ps, input, null, cycle);
			}

			// case: BsonValue
			var bson = value as BsonValue;
			if (bson != null)
				return bson;

			// case: string
			var text = value as string;
			if (text != null)
				return new BsonString(text);

			// case: dictionary
			var dictionary = value as IDictionary;
			if (dictionary != null)
				return ToBsonDocumentFromDictionary(dictionary, input, null, cycle);

			// case: collection
			var enumerable = value as IEnumerable;
			if (enumerable != null)
			{
				PushCycle(enumerable, ref cycle);
				try
				{
					var array = new BsonArray();
					foreach (var it in enumerable)
						array.Add(ToBsonValue(it, input, cycle));
					return array;
				}
				finally
				{
					PopCycle(cycle);
				}
			}

			// try to create BsonValue
			try
			{
				return BsonValue.Create(value);
			}
			catch (ArgumentException ae)
			{
				if (input == null)
					throw;

				try
				{
					value = input.ConvertValue(value);
				}
				catch (RuntimeException re)
				{
					throw new ArgumentException( //! use this type
						string.Format(CultureInfo.InvariantCulture, @"Converter script was called on ""{0}"" and failed with ""{1}"".", ae.Message, re.Message), re);
				}

				if (value == null)
					throw;

				// do not call converter twice
				return ToBsonValue(value, null, cycle);
			}
		}
		static BsonDocument ToBsonDocumentFromDictionary(IDictionary dictionary, DocumentInput input, IEnumerable<Selector> properties, ArrayList cycle)
		{
			PushCycle(dictionary, ref cycle);
			try
			{
				//_131013_155413 Mdbc.Dictionary
				if (properties == null)
				{
					var md = dictionary as Dictionary;
					if (md != null)
						return md.Document();
				}

				var document = new BsonDocument();
				if (properties == null)
				{
					foreach (DictionaryEntry de in dictionary)
					{
						var name = de.Key as string;
						if (name == null)
							throw new InvalidOperationException("Dictionary keys must be strings.");

						document.Add(name, ToBsonValue(de.Value, input, cycle));
					}
				}
				else
				{
					foreach (var selector in properties)
					{
						if (selector.PropertyName != null)
						{
							if (dictionary.Contains(selector.PropertyName))
								document.Add(selector.DocumentName, ToBsonValue(dictionary[selector.PropertyName], input, cycle));
						}
						else
						{
							document.Add(selector.DocumentName, ToBsonValue(selector.GetValue(dictionary), input, cycle));
						}
					}
				}

				return document;
			}
			finally
			{
				PopCycle(cycle);
			}
		}
		// Input supposed to be not null
		static BsonDocument ToBsonDocumentFromProperties(PSObject value, DocumentInput input, IEnumerable<Selector> properties, ArrayList cycle)
		{
			PushCycle((value.BaseObject is PSCustomObject ? value : value.BaseObject), ref cycle);
			try
			{
				var document = new BsonDocument();
				if (properties == null)
				{
					foreach (var pi in value.Properties)
					{
						try
						{
							document.Add(pi.Name, ToBsonValue(pi.Value, input, cycle));
						}
						catch (GetValueException) // .Value may throw, e.g. ExitCode in Process
						{
							document.Add(pi.Name, BsonNull.Value);
						}
					}
				}
				else
				{
					foreach (var selector in properties)
					{
						if (selector.PropertyName != null)
						{
							var pi = value.Properties[selector.PropertyName];
							if (pi != null)
							{
								try
								{
									document.Add(selector.DocumentName, ToBsonValue(pi.Value, input, cycle));
								}
								catch (GetValueException) // .Value may throw, e.g. ExitCode in Process
								{
									document.Add(selector.DocumentName, BsonNull.Value);
								}
							}
						}
						else
						{
							document.Add(selector.DocumentName, ToBsonValue(selector.GetValue(value), input, cycle));
						}
					}
				}
				return document;
			}
			finally
			{
				PopCycle(cycle);
			}
		}
		public static BsonDocument ToBsonDocument(object value, DocumentInput input, IEnumerable<Selector> properties)
		{
			return ToBsonDocument(value, input, properties, null);
		}
		static BsonDocument ToBsonDocument(object value, DocumentInput input, IEnumerable<Selector> properties, ArrayList cycle)
		{
			var ps = value as PSObject;
			if (ps != null)
				value = ps.BaseObject;

			//_131013_155413 BsonDocument
			var document = value as BsonDocument;
			if (document != null)
			{
				if (properties == null)
					return document;

				value = new Dictionary(document);
			}

			var dictionary = value as IDictionary;
			if (dictionary != null)
				return ToBsonDocumentFromDictionary(dictionary, input, properties, cycle);

			return ToBsonDocumentFromProperties(ps ?? PSObject.AsPSObject(value), input, properties, cycle);
		}
		public static IEnumerable<BsonValue> ToEnumerableBsonValue(object value)
		{
			var bv = ToBsonValue(value);
			var ba = bv as BsonArray;
			if (ba == null)
				return new[] { bv };
			else
				return ba;
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
			{
				value = ps.BaseObject;

				if (value is PSCustomObject)
				{
					var id = ps.Properties["_id"];
					if (id == null)
						throw new InvalidOperationException("Custom object: expected property _id.");

					return Query.EQ("_id", BsonValue.Create(id.Value));
				}
			}

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
		public static IMongoUpdate ObjectToUpdate(object value)
		{
			var ps = value as PSObject;
			if (ps != null)
				value = ps.BaseObject;

			var update = value as IMongoUpdate;
			if (update != null)
				return update;

			var dictionary = value as IDictionary;
			if (dictionary != null) //1310111530
				return new UpdateDocument(dictionary);

			var enumerable = LanguagePrimitives.GetEnumerable(value);
			if (enumerable != null)
				return Update.Combine(enumerable.Cast<object>().Select(Actor.ObjectToUpdate));

			throw new PSInvalidCastException("Invalid update type. Valid types: update, dictionary.");
		}
		static void PushCycle(object value, ref ArrayList cycle)
		{
			if (cycle == null)
			{
				cycle = new ArrayList();
			}
			else
			{
				foreach (var it in cycle)
				{
					if (object.ReferenceEquals(it, value))
						throw new InvalidOperationException("Cyclic reference.");
				}
				cycle.Add(value);
			}
		}
		static void PopCycle(ArrayList cycle)
		{
			if (cycle.Count > 0)
				cycle.RemoveAt(cycle.Count - 1);
		}
	}
}
