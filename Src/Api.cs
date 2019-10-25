
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Management.Automation;
using MongoDB.Bson;
using MongoDB.Bson.IO;
using MongoDB.Bson.Serialization;
using MongoDB.Driver;

namespace Mdbc
{
	public static class Api
	{
		public const string ErrorEmptyDocument = "Document must not be empty.";
		public const string TextParameterCommand = "Parameter Command must be specified and cannot be null.";
		public const string TextParameterFilter = "Parameter Filter must be specified and cannot be null.";
		public const string TextParameterPipeline = "Parameter Pipeline must be specified and cannot be null.";
		public const string TextParameterSet = "Parameter Set must be specified and cannot be null.";
		public const string TextParameterUpdate = "Parameter Update must be specified and cannot be null.";
		static object BaseObjectNotNull(object value)
		{
			if (value == null) throw new ArgumentNullException(nameof(value));
			return value is PSObject ps ? ps.BaseObject : value;
		}
		static BsonValue JsonToBsonValue(string json)
		{
			Debug.Assert(json != null);
			try
			{
				var serializer = BsonSerializer.LookupSerializer(typeof(BsonValue));
				using (var reader1 = new StringReader(json))
				{
					using (var reader2 = new JsonReader(reader1))
					{
						var context = BsonDeserializationContext.CreateRoot(reader2);
						return (BsonValue)serializer.Deserialize(context);
					}
				}
			}
			catch (Exception exn)
			{
				throw new ArgumentException("Invalid JSON.", exn);
			}
		}
		static BsonDocument JsonToBsonDocument(string json)
		{
			var bson = JsonToBsonValue(json);
			if (bson.BsonType == BsonType.Document)
				return bson.AsBsonDocument;
			else
				throw new ArgumentException($"JSON: expected document, found {bson.BsonType}.");
		}
		/// <summary>
		/// IConvertibleToBsonDocument, IDictionary, or JSON.
		/// </summary>
		static BsonDocument BsonDocument(object value)
		{
			// unwrap, it may be PSObject item of PS array, see _191103_084410
			value = BaseObjectNotNull(value);

			//! before IDictionary, mind Mdbc.Dictionary
			if (value is IConvertibleToBsonDocument cd)
				return cd.ToBsonDocument();

			//! after IConvertibleToBsonDocument
			if (value is IDictionary dictionary)
				return new BsonDocument(dictionary);

			if (value is string json)
				return JsonToBsonDocument(json);

			throw new ArgumentException($"Cannot convert {value.GetType().FullName} to {nameof(BsonDocument)}");
		}
		/// <summary>
		/// IConvertibleToBsonDocument, IDictionary, or JSON.
		/// </summary>
		static bool TryBsonDocument(object value, out BsonDocument result)
		{
			// unwrap, it may be PSObject item of PS array, see _191103_084410
			value = BaseObjectNotNull(value);

			//! before IDictionary, mind Mdbc.Dictionary
			if (value is IConvertibleToBsonDocument cd)
			{
				result = cd.ToBsonDocument();
				return true;
			}

			//! after IConvertibleToBsonDocument
			if (value is IDictionary dictionary)
			{
				result = new BsonDocument(dictionary);
				return true;
			}

			if (value is string json)
			{
				result = JsonToBsonDocument(json);
				return true;
			}

			result = null;
			return false;
		}
		public static Command<BsonDocument> Command(object value)
		{
			value = BaseObjectNotNull(value);

			if (TryBsonDocument(value, out var doc))
			{
				if (doc.ElementCount == 0) throw new ArgumentException(Api.ErrorEmptyDocument);
				return doc;
			}

			return (Command<BsonDocument>)value;
		}
		public static PipelineDefinition<BsonDocument, BsonDocument> PipelineDefinition(object value)
		{
			value = BaseObjectNotNull(value);

			// JSON first because it looks very convenient for pipelines
			if (value is string json)
			{
				var bson = JsonToBsonValue(json);
				switch (bson.BsonType)
				{
					case BsonType.Array:
						return bson.AsBsonArray.Select(x => x.AsBsonDocument).ToList();
					case BsonType.Document:
						return new BsonDocument[] { bson.AsBsonDocument };
					default:
						throw new ArgumentException($"JSON: expected array or document, found {bson.BsonType}.");
				}
			}

			//! before IDictionary, mind Mdbc.Dictionary
			if (value is IConvertibleToBsonDocument cd)
				return new BsonDocument[] { cd.ToBsonDocument() };

			//! after IConvertibleToBsonDocument
			if (value is IDictionary dictionary)
				return new BsonDocument[] { new BsonDocument(dictionary) };

			// PS arrays or other collections
			if (value is IEnumerable en)
			{
				var list = new List<BsonDocument>();
				foreach (var it in en)
					list.Add(BsonDocument(it));
				return list;
			}

			// either PipelineDefinition (unlikely but possible) or "Cannot cast X to Y"
			return (PipelineDefinition<BsonDocument, BsonDocument>)value;
		}
		public static UpdateDefinition<BsonDocument> UpdateDefinition(object value)
		{
			value = BaseObjectNotNull(value);

			if (TryBsonDocument(value, out var doc))
			{
				if (doc.ElementCount == 0) throw new ArgumentException(Api.ErrorEmptyDocument);
				return doc;
			}

			if (value is IEnumerable)
				return PipelineDefinition(value);

			return (UpdateDefinition<BsonDocument>)value;
		}
	}
}
