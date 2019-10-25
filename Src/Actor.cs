
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Management.Automation;
using MongoDB.Bson;
using MongoDB.Bson.IO;
using MongoDB.Bson.Serialization;
using MongoDB.Driver;

namespace Mdbc
{
	static class Actor
	{
		public const string ClientVariable = "Client";
		public const string DatabaseVariable = "Database";
		public const string CollectionVariable = "Collection";

		// NB: Change of the global defaults affects ToString().
		// `Strict` (like mongoexport) is tempting, other tools may read it.
		// But `Strict` is not suitable for reading and searching. Also, it
		// looses number types (numbers are double). `Shell` (default) keeps
		// types and readable for _id, dates, GUID. So let's use `Shell` not
		// directly but via defaults. If needed defaults can be changed by a
		// user.
		public static JsonWriterSettings DefaultJsonWriterSettings
		{
			get { return JsonWriterSettings.Defaults; }
		}
		/// <summary>
		/// null | PSObject.BaseObject | self
		/// </summary>
		public static object BaseObject(object value)
		{
			return value == null ? null : value is PSObject ps ? ps.BaseObject : value;
		}
		/// <summary>
		/// null | PSCustomObject | PSObject.BaseObject | self
		/// </summary>
		public static object BaseObject(object value, out PSObject custom)
		{
			custom = null;

			if (value == null)
				return null;

			if (!(value is PSObject ps))
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

			if (value is PSObject ps)
				value = ps.BaseObject;

			if (!(value is IEnumerable en))
				return null;

			if (value is string)
				return null;

			return en;
		}
		public static object ToObject(BsonValue value) //_120509_173140 sync
		{
			if (value == null)
				return null;

			switch (value.BsonType)
			{
				case BsonType.Array: return new Collection((BsonArray)value); // wrapper
				case BsonType.Boolean: return ((BsonBoolean)value).Value;
				case BsonType.DateTime: return ((BsonDateTime)value).ToUniversalTime();
				case BsonType.Document: return new Dictionary((BsonDocument)value); // wrapper
				case BsonType.Double: return ((BsonDouble)value).Value;
				case BsonType.Int32: return ((BsonInt32)value).Value;
				case BsonType.Int64: return ((BsonInt64)value).Value;
				case BsonType.Null: return null;
				case BsonType.ObjectId: return ((BsonObjectId)value).Value;
				case BsonType.String: return ((BsonString)value).Value;
				case BsonType.Binary:
					var data = (BsonBinaryData)value;
					switch (data.SubType)
					{
						case BsonBinarySubType.UuidLegacy:
						case BsonBinarySubType.UuidStandard:
							return data.ToGuid();
						default:
							return data;
					}
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

			value = BaseObject(value, out PSObject custom);

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

			value = BaseObject(value, out PSObject custom);

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
		public static FilterDefinition<BsonDocument> ObjectToFilter(object value)
		{
			if (value == null)
				return null;

			value = BaseObject(value);

			//! before IDictionary, mind Mdbc.Dictionary
			if (value is IConvertibleToBsonDocument cd)
				return cd.ToBsonDocument();

			//! after IConvertibleToBsonDocument
			if (value is IDictionary dictionary)
				return new BsonDocument(dictionary);

			if (value is string json)
				return json.Length == 0 ? null : json;

			return (FilterDefinition<BsonDocument>)value;
		}
		public static SortDefinition<BsonDocument> ObjectToSort(object value)
		{
			if (value == null)
				return null;

			value = BaseObject(value);

			//! before IDictionary, mind Mdbc.Dictionary
			if (value is IConvertibleToBsonDocument cd)
				return cd.ToBsonDocument();

			//! after IConvertibleToBsonDocument
			if (value is IDictionary dictionary)
				return new BsonDocument(dictionary);

			if (value is string json)
				return json;

			return (SortDefinition<BsonDocument>)value;
		}
		public static ProjectionDefinition<BsonDocument> ObjectsToProject(object value)
		{
			if (value == null)
				return null;

			value = BaseObject(value);

			//! before IDictionary, mind Mdbc.Dictionary
			if (value is IConvertibleToBsonDocument cd)
				return cd.ToBsonDocument();

			//! after IConvertibleToBsonDocument
			if (value is IDictionary dictionary)
				return new BsonDocument(dictionary);

			if (value is string json)
				return json;

			return (ProjectionDefinition<BsonDocument>)value;
		}
		static void IncSerializationDepth(ref int depth)
		{
			if (++depth > BsonDefaults.MaxSerializationDepth)
				throw new InvalidOperationException("Data exceed the default maximum serialization depth.");
		}
		/// <summary>
		/// Gets function converting BsonDocument to the specified type.
		/// It works effectively for Mdbc.Dictionary and BsonDocument.
		/// Other types are serialized.
		/// </summary>
		public static Func<BsonDocument, object> ConvertDocument(Type outputType)
		{
			if (outputType == typeof(Dictionary))
				return x => new Dictionary(x);

			if (outputType == typeof(BsonDocument))
				return x => x;

			var serializer = BsonSerializer.LookupSerializer(outputType);
			return x =>
			{
				var context = BsonDeserializationContext.CreateRoot(new BsonDocumentReader(x));
				return serializer.Deserialize(context);
			};
		}
	}
}
