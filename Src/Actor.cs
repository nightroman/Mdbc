
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
using System.Linq;
using System.Management.Automation;
using MongoDB.Bson;
using MongoDB.Bson.Serialization;
using MongoDB.Driver;
using MongoDB.Driver.Builders;

namespace Mdbc
{
	static class Actor
	{
		public const string ServerVariable = "Server";
		public const string DatabaseVariable = "Database";
		public const string CollectionVariable = "Collection";
		static bool _registered;
		public static void Register()
		{
			if (_registered)
				return;

			_registered = true;

			BsonSerializer.RegisterSerializer(typeof(Dictionary), new DictionarySerializer());
			BsonSerializer.RegisterSerializer(typeof(LazyDictionary), new LazyDictionarySerializer());
			BsonSerializer.RegisterSerializer(typeof(RawDictionary), new RawDictionarySerializer());
			BsonSerializer.RegisterSerializer(typeof(PSObject), new PSObjectSerializer());

			BsonTypeMapper.RegisterCustomTypeMapper(typeof(PSObject), new PSObjectTypeMapper());
		}
		public static object BaseObject(object value)
		{
			if (value == null)
				return value;
			var ps = value as PSObject;
			return ps == null ? value : ps.BaseObject;
		}
		public static object BaseObject(object value, out PSObject custom)
		{
			custom = null;
			if (value == null)
				return value;
			var ps = value as PSObject;
			if (ps == null)
				return value;
			if (!(ps.BaseObject is PSCustomObject))
				return ps.BaseObject;
			custom = ps;
			return ps;
		}
		public static IEnumerable AsEnumerable(object value)
		{
			if (value == null)
				return null;
			var ps = value as PSObject;
			value = ps == null ? value : ps.BaseObject;
			IEnumerable enumerable;
			if (null == (enumerable = value as IEnumerable))
				return null;
			if (value is string)
				return null;
			return enumerable;
		}
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
		//! For external use only.
		public static BsonValue ToBsonValue(object value)
		{
			return ToBsonValue(value, null, 0);
		}
		static BsonValue ToBsonValue(object value, DocumentInput input, int depth)
		{
			IncSerializationDepth(ref depth);

			if (value == null)
				return BsonNull.Value;

			PSObject custom;
			value = BaseObject(value, out custom);

			// case: custom
			if (custom != null)
				return ToBsonDocumentFromProperties(null, custom, input, null, depth);

			// case: BsonValue
			var bson = value as BsonValue;
			if (bson != null)
				return bson;

			// case: string
			var text = value as string;
			if (text != null)
				return new BsonString(text);

			// case: document
			var cd = value as IConvertibleToBsonDocument;
			if (cd != null)
				return cd.ToBsonDocument();

			// case: dictionary
			var dictionary = value as IDictionary;
			if (dictionary != null)
				return ToBsonDocumentFromDictionary(null, dictionary, input, null, depth);

			// case: collection
			var enumerable = value as IEnumerable;
			if (enumerable != null)
			{
				var array = new BsonArray();
				foreach (var it in enumerable)
					array.Add(ToBsonValue(it, input, depth));
				return array;
			}

			// try to create BsonValue
			try
			{
				Register();
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
						string.Format(null, @"Converter script was called on ""{0}"" and failed with ""{1}"".", ae.Message, re.Message), re);
				}

				if (value == null)
					throw;

				// do not call converter twice
				return ToBsonValue(value, null, depth);
			}
		}
		//! IConvertibleToBsonDocument (e.g. Mdbc.Dictionary) must be converted before if source and properties are null
		static BsonDocument ToBsonDocumentFromDictionary(BsonDocument source, IDictionary dictionary, DocumentInput input, IEnumerable<Selector> properties, int depth)
		{
			IncSerializationDepth(ref depth);

#if DEBUG
			if (source == null && properties == null && dictionary is IConvertibleToBsonDocument)
				throw new InvalidOperationException("DEBUG: must be converted before.");
#endif

			// use source or new document
			var document = source ?? new BsonDocument();

			if (properties == null)
			{
				foreach (DictionaryEntry de in dictionary)
				{
					var name = de.Key as string;
					if (name == null)
						throw new InvalidOperationException("Dictionary keys must be strings.");

					document.Add(name, ToBsonValue(de.Value, input, depth));
				}
			}
			else
			{
				foreach (var selector in properties)
				{
					if (selector.PropertyName != null)
					{
						if (dictionary.Contains(selector.PropertyName))
							document.Add(selector.DocumentName, ToBsonValue(dictionary[selector.PropertyName], input, depth));
					}
					else
					{
						document.Add(selector.DocumentName, ToBsonValue(selector.GetValue(dictionary), input, depth));
					}
				}
			}

			return document;
		}
		// Input supposed to be not null
		static BsonDocument ToBsonDocumentFromProperties(BsonDocument source, PSObject value, DocumentInput input, IEnumerable<Selector> properties, int depth)
		{
			IncSerializationDepth(ref depth);

			var type = value.BaseObject.GetType();
			if (type.IsPrimitive || type == typeof(string))
				throw new InvalidCastException(string.Format(null, "Cannot convert {0} to a document.", type));

			// existing or new document
			var document = source ?? new BsonDocument();

			if (properties == null)
			{
				foreach (var pi in value.Properties)
				{
					try
					{
						document.Add(pi.Name, ToBsonValue(pi.Value, input, depth));
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
								document.Add(selector.DocumentName, ToBsonValue(pi.Value, input, depth));
							}
							catch (GetValueException) // .Value may throw, e.g. ExitCode in Process
							{
								document.Add(selector.DocumentName, BsonNull.Value);
							}
						}
					}
					else
					{
						document.Add(selector.DocumentName, ToBsonValue(selector.GetValue(value), input, depth));
					}
				}
			}
			return document;
		}
		//! For external use only.
		public static BsonDocument ToBsonDocument(object value)
		{
			return ToBsonDocument(null, value, null, null, 0);
		}
		//! For external use only.
		public static BsonDocument ToBsonDocument(BsonDocument source, object value, DocumentInput input, IEnumerable<Selector> properties)
		{
			return ToBsonDocument(source, value, input, properties, 0);
		}
		static BsonDocument ToBsonDocument(BsonDocument source, object value, DocumentInput input, IEnumerable<Selector> properties, int depth)
		{
			IncSerializationDepth(ref depth);

			PSObject custom;
			value = BaseObject(value, out custom);

			//_131013_155413 reuse existing document or wrap
			var cd = value as IConvertibleToBsonDocument;
			if (cd != null)
			{
				// reuse
				if (source == null && properties == null)
					return cd.ToBsonDocument();

				// wrap
				return ToBsonDocumentFromDictionary(source, new Dictionary(cd), input, properties, depth);
			}

			var dictionary = value as IDictionary;
			if (dictionary != null)
				return ToBsonDocumentFromDictionary(source, dictionary, input, properties, depth);

			return ToBsonDocumentFromProperties(source, custom ?? new PSObject(value), input, properties, depth);
		}
		public static IEnumerable<BsonValue> ToEnumerableBsonValue(object value)
		{
			var bv = ToBsonValue(value, null, 0);
			var ba = bv as BsonArray;
			if (ba == null)
				return new[] { bv };
			else
				return ba;
		}
		static IMongoQuery IdToQuery(object id)
		{
			Register();
			var value = BsonValue.Create(id);

			if (value.BsonType == BsonType.Array)
				throw new ArgumentException("_id cannot be an array."); //_131110_085122

			return Query.EQ(MyValue.Id, value);
		}
		public static IMongoQuery ObjectToQuery(object value)
		{
			if (value == null)
				return Query.Null;

			value = BaseObject(value);

			var query = value as IMongoQuery;
			if (query != null)
				return query;

			var cd = value as IConvertibleToBsonDocument;
			if (cd != null)
				return new QueryDocument(cd.ToBsonDocument());

			var dictionary = value as IDictionary;
			if (dictionary != null)
				return new QueryDocument(dictionary);

			return IdToQuery(value);
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
				if (hash == null) throw new ArgumentException("SortBy: Invalid size object type.");
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
		public static IMongoFields ObjectsToFields(IList<object> values)
		{
			if (values == null)
				return null;

			IMongoFields fields;
			if (values.Count == 1 && (fields = values[0] as IMongoFields) != null)
				return fields;

			var builder = new FieldsBuilder();
			foreach (var it in values)
			{
				var name = it as string;
				if (name != null)
				{
					builder.Include(name);
					continue;
				}
				throw new ArgumentException("Property: Expected either one IMongoFields or one or more String.");
			}
			return builder;
		}
		public static IMongoUpdate ObjectToUpdate(object value, Action<string> error)
		{
			value = BaseObject(value);

			var update = value as IMongoUpdate;
			if (update != null)
				return update;

			var dictionary = value as IDictionary;
			if (dictionary != null)
				return new UpdateDocument(dictionary);

			var enumerable = value as IEnumerable;
			if (enumerable != null && !(value is string))
				return Update.Combine(enumerable.Cast<object>().Select(x => ObjectToUpdate(x, error)));

			var message = string.Format(null, "Invalid update object type: {0}. Valid types: update(s), dictionary(s).", value.GetType());
			if (error == null)
				throw new ArgumentException(message);

			error(message);
			return null;
		}
		public static IEnumerable<BsonDocument> ObjectToBsonDocuments(object value)
		{
			var r = new List<BsonDocument>();
			if (value == null)
				return r;

			var enumerable = AsEnumerable(value);
			if (enumerable == null)
				r.Add(ToBsonDocument(null, value, null, null, 0));
			else
				foreach (var it in enumerable)
					r.Add(ToBsonDocument(null, it, null, null, 0));

			return r;
		}
		static void IncSerializationDepth(ref int depth)
		{
			if (++depth > BsonDefaults.MaxSerializationDepth)
				throw new InvalidOperationException("Data exceed the default maximum serialization depth.");
		}
	}
}
