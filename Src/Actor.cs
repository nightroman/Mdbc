
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Bson;
using MongoDB.Bson.IO;
using MongoDB.Bson.Serialization;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Management.Automation;

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
		public static object ToObject(BsonValue value) //_120509_173140 sync, test
		{
			if (value == null)
				return null;

			switch (value.BsonType)
			{
				case BsonType.Array: return new Collection((BsonArray)value); // wrapper
				case BsonType.Boolean: return ((BsonBoolean)value).Value;
				case BsonType.DateTime: return ((BsonDateTime)value).ToUniversalTime();
				case BsonType.Decimal128: return ((BsonDecimal128)value).ToDecimal();
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
		static BsonValue ToBsonValue(object value, ScriptBlock convert, int depth)
		{
			IncSerializationDepth(ref depth);

			if (value == null)
				return BsonNull.Value;

			value = BaseObject(value, out PSObject custom);

			// case: custom
			if (custom != null)
				return ToBsonDocumentFromProperties(null, custom, convert, null, depth);

			// case: BsonValue
			if (value is BsonValue bson)
				return bson;

			// case: string
			if (value is string text)
				return new BsonString(text);

			// case: document
			if (value is IConvertibleToBsonDocument cd)
				return cd.ToBsonDocument();

			// case: dictionary
			if (value is IDictionary dictionary)
				return ToBsonDocumentFromDictionary(null, dictionary, convert, null, depth);

			// case: bytes or collection
			if (value is IEnumerable en)
			{
				//_191108_183844
				if (en is byte[] bytes)
					return new BsonBinaryData(bytes);

				var array = new BsonArray();
				foreach (var it in en)
					array.Add(ToBsonValue(it, convert, depth));
				return array;
			}

			// try to map BsonValue
			if (BsonTypeMapper.TryMapToBsonValue(value, out BsonValue bson2))
				return bson2;

			// try to serialize class
			var type = value.GetType();
			if (TypeIsDriverSerialized(type))
				return BsonExtensionMethods.ToBsonDocument(value, type);

			// no converter? die
			if (convert == null)
				//! use this type
				throw new ArgumentException(Res.CannotConvert2(type, nameof(BsonValue)));

			try
			{
				value = DocumentInput.ConvertValue(convert, value);
			}
			catch (RuntimeException re)
			{
				//! use this type
				throw new ArgumentException($"Converter script was called for '{type}' and failed with '{re.Message}'.", re);
			}

			// do not pass converter twice
			return ToBsonValue(value, null, depth);
		}
		//! IConvertibleToBsonDocument (e.g. Mdbc.Dictionary) must be converted before if source and properties are null
		static BsonDocument ToBsonDocumentFromDictionary(BsonDocument source, IDictionary dictionary, ScriptBlock convert, IList<Selector> properties, int depth)
		{
			IncSerializationDepth(ref depth);

#if DEBUG
			if (source == null && properties == null && dictionary is IConvertibleToBsonDocument)
				throw new InvalidOperationException("DEBUG: must be converted before.");
#endif

			// use source or new document
			var document = source ?? new BsonDocument();

			if (properties == null || properties.Count == 0)
			{
				foreach (DictionaryEntry de in dictionary)
				{
					if (de.Key is string name)
						document.Add(name, ToBsonValue(de.Value, convert, depth));
					else
						throw new InvalidOperationException("Dictionary keys must be strings.");
				}
			}
			else
			{
				foreach (var selector in properties)
				{
					if (selector.PropertyName != null)
					{
						if (dictionary.Contains(selector.PropertyName))
							document.Add(selector.DocumentName, ToBsonValue(dictionary[selector.PropertyName], convert, depth));
					}
					else
					{
						document.Add(selector.DocumentName, ToBsonValue(selector.GetValue(dictionary), convert, depth));
					}
				}
			}

			return document;
		}
		internal static bool TypeIsDriverSerialized(Type type)
		{
			return ClassMap.Contains(type);
		}
		// Input supposed to be not null
		static BsonDocument ToBsonDocumentFromProperties(BsonDocument source, PSObject value, ScriptBlock convert, IList<Selector> properties, int depth)
		{
			IncSerializationDepth(ref depth);

			var type = value.BaseObject.GetType();
			if (type.IsPrimitive || type == typeof(string))
				throw new InvalidOperationException(Res.CannotConvert2(type, nameof(BsonDocument)));

			// propertied omitted (null) of all (0)?
			if (properties == null || properties.Count == 0)
			{
				// if properties omitted (null) and the top (1) native object is not custom
				if (properties == null && depth == 1 && (!(value.BaseObject is PSCustomObject)) && TypeIsDriverSerialized(type))
				{
					try
					{
						// serialize the top level native object
						var document = BsonExtensionMethods.ToBsonDocument(value.BaseObject, type);

						// return the result
						if (source == null)
							return document;

						// add to the provided document
						source.AddRange(document.Elements);
						return source;
					}
					catch (SystemException exn)
					{
						throw new InvalidOperationException(Res.CannotConvert3(type, nameof(BsonDocument), exn.Message), exn);
					}
				}
				else
				{
					// convert all properties to the source or new document
					var document = source ?? new BsonDocument();
					foreach (var pi in value.Properties)
					{
						try
						{
							document.Add(pi.Name, ToBsonValue(pi.Value, convert, depth));
						}
						catch (GetValueException) // .Value may throw, e.g. ExitCode in Process
						{
							document.Add(pi.Name, BsonNull.Value);
						}
						catch (SystemException exn)
						{
							if (depth == 1)
								throw new InvalidOperationException(Res.CannotConvert3(type, nameof(BsonDocument), exn.Message), exn);
							else
								throw;
						}
					}
					return document;
				}
			}
			else
			{
				// existing or new document
				var document = source ?? new BsonDocument();
				foreach (var selector in properties)
				{
					if (selector.PropertyName != null)
					{
						var pi = value.Properties[selector.PropertyName];
						if (pi != null)
						{
							try
							{
								document.Add(selector.DocumentName, ToBsonValue(pi.Value, convert, depth));
							}
							catch (GetValueException) // .Value may throw, e.g. ExitCode in Process
							{
								document.Add(selector.DocumentName, BsonNull.Value);
							}
						}
					}
					else
					{
						document.Add(selector.DocumentName, ToBsonValue(selector.GetValue(value), convert, depth));
					}
				}
				return document;
			}
		}
		//! For external use only.
		public static BsonDocument ToBsonDocument(object value)
		{
			return ToBsonDocument(null, value, null, null, 0);
		}
		//! For external use only.
		public static BsonDocument ToBsonDocument(BsonDocument source, object value, ScriptBlock convert, IList<Selector> properties)
		{
			return ToBsonDocument(source, value, convert, properties, 0);
		}
		//! For external use only.
		internal static BsonDocument ToBsonDocumentFromDictionary(IDictionary value)
		{
			return ToBsonDocumentFromDictionary(null, value, null, null, 0);
		}
		static BsonDocument ToBsonDocument(BsonDocument source, object value, ScriptBlock convert, IList<Selector> properties, int depth)
		{
			value = BaseObject(value, out PSObject custom);

			//_131013_155413 reuse existing document or wrap
			if (value is IConvertibleToBsonDocument cd)
			{
				var document = cd.ToBsonDocument();

				// reuse
				if (source == null && properties == null)
					return document;

				// wrap, we need IDictionary, BsonDocument is not
				return ToBsonDocumentFromDictionary(source, new Dictionary(document), convert, properties, depth);
			}

			if (value is IDictionary dictionary)
				return ToBsonDocumentFromDictionary(source, dictionary, convert, properties, depth);

			return ToBsonDocumentFromProperties(source, custom ?? new PSObject(value), convert, properties, depth);
		}
		static void IncSerializationDepth(ref int depth)
		{
			if (++depth > BsonDefaults.MaxSerializationDepth)
				throw new InvalidOperationException("Data exceed the default maximum serialization depth.");
		}
		//_191112_180148
		static void ConfigureBsonDeserializationContext(BsonDeserializationContext.Builder builder)
		{
			builder.DynamicArraySerializer = new CollectionSerializer();
			builder.DynamicDocumentSerializer = new DictionarySerializer();
		}
		/// <summary>
		/// Gets function converting BsonDocument to the specified type.
		/// It works effectively for Mdbc.Dictionary and BsonDocument.
		/// Other types are serialized.
		/// </summary>
		public static Func<BsonDocument, object> ConvertDocument(Type outputType)
		{
			// return wrapped by Dictionary
			if (outputType == typeof(Dictionary))
				return x => new Dictionary(x);

			// return as is
			if (outputType == typeof(BsonDocument))
				return x => x;

			// deserialize, mind object, simple, serial cases
			var serializer = BsonSerializer.LookupSerializer(outputType);
			return x =>
			{
				var context = BsonDeserializationContext.CreateRoot(new BsonDocumentReader(x));

				//_191115_060729 Simple types: read untyped containers as Mdbc containers
				if (outputType != typeof(object) && !TypeIsDriverSerialized(outputType))
					context = context.With(ConfigureBsonDeserializationContext);

				return serializer.Deserialize(context);
			};
		}
		public static Collection<PSObject> InvokeScript(ScriptBlock script, object value)
		{
			var vars = new List<PSVariable>() { new PSVariable("_", value) };
			return script.InvokeWithContext(null, vars);
		}
	}
}
