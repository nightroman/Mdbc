
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Bson;
using MongoDB.Bson.IO;
using MongoDB.Bson.Serialization;
using MongoDB.Driver;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Management.Automation;

namespace Mdbc
{
	public static class Api
	{
		#region Messages
		public const string ErrorEmptyDocument = "Document must not be empty.";
		public const string TextParameterCommand = "Parameter Command must be specified and cannot be null.";
		public const string TextParameterFilter = "Parameter Filter must be specified and cannot be null or empty string. To match all, use an empty document.";
		public const string TextParameterFilterInput = "Parameter Filter must be omitted with pipeline input.";
		public const string TextParameterPipeline = "Parameter Pipeline must be specified and cannot be null.";
		public const string TextParameterSet = "Parameter Set must be specified and cannot be null.";
		public const string TextParameterUpdate = "Parameter Update must be specified and cannot be null.";
		public const string TextInputDocNull = "Input document cannot be null.";
		public const string TextInputDocId = "Input document must have _id.";

		internal static string TextCannotConvert2(object from, object to)
		{
			return $"Cannot convert '{from}' to '{to}'.";
		}
		internal static string TextCannotConvert3(object from, object to, string error)
		{
			return $"{TextCannotConvert2(from, to)} -- {error}";
		}
		#endregion

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
		internal static BsonDocument JsonToBsonDocument(string json)
		{
			var bson = JsonToBsonValue(json);
			if (bson.BsonType == BsonType.Document)
				return bson.AsBsonDocument;
			else
				throw new ArgumentException($"JSON: expected document, found {bson.BsonType}.");
		}
		/// <summary>
		/// JSON, IConvertibleToBsonDocument, IDictionary.
		/// </summary>
		internal static BsonDocument BsonDocument(object value)
		{
			// unwrap, it may be PSObject item of PS array, see _191103_084410
			value = BaseObjectNotNull(value);

			if (value is string json)
				return JsonToBsonDocument(json);

			//! before IDictionary, mind Mdbc.Dictionary
			if (value is IConvertibleToBsonDocument cd)
				return cd.ToBsonDocument();

			//! after IConvertibleToBsonDocument
			if (value is IDictionary dictionary)
				return Actor.ToBsonDocumentFromDictionary(dictionary);

			throw new InvalidOperationException(Api.TextCannotConvert2(value.GetType(), nameof(BsonDocument)));
		}
		/// <summary>
		/// JSON, IConvertibleToBsonDocument, IDictionary.
		/// </summary>
		static bool TryBsonDocument(object value, out BsonDocument result)
		{
			// unwrap, it may be PSObject item of PS array, see _191103_084410
			value = BaseObjectNotNull(value);

			if (value is string json)
			{
				result = JsonToBsonDocument(json);
				return true;
			}

			//! before IDictionary, mind Mdbc.Dictionary
			if (value is IConvertibleToBsonDocument cd)
			{
				result = cd.ToBsonDocument();
				return true;
			}

			//! after IConvertibleToBsonDocument
			if (value is IDictionary dictionary)
			{
				result = Actor.ToBsonDocumentFromDictionary(dictionary);
				return true;
			}

			result = null;
			return false;
		}
		/// <summary>
		/// Null, empty string, JSON, IConvertibleToBsonDocument, IDictionary.
		/// </summary>
		// Used for optional -Filter, -Sort, -Project. They may be omitted,
		// nulls or empty strings (e.g. nulls converted to strings by PS).
		static bool TryBsonDocumentOrNull(object value, out BsonDocument result)
		{
			if (value == null)
			{
				result = null;
				return true;
			}

			value = Actor.BaseObject(value);

			if (value is string json)
			{
				result = json.Length == 0 ? null : JsonToBsonDocument(json);
				return true;
			}

			//! before IDictionary, mind Mdbc.Dictionary
			if (value is IConvertibleToBsonDocument cd)
			{
				result = cd.ToBsonDocument();
				return true;
			}

			//! after IConvertibleToBsonDocument
			if (value is IDictionary dictionary)
			{
				result = Actor.ToBsonDocumentFromDictionary(dictionary);
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
		public static FilterDefinition<BsonDocument> FilterDefinition(object value)
		{
			if (TryBsonDocumentOrNull(value, out var doc))
				return doc;

			return (FilterDefinition<BsonDocument>)value;
		}
		public static FilterDefinition<BsonDocument> FilterDefinitionOfId(object value)
		{
			value = Actor.BaseObject(value);
			return Builders<BsonDocument>.Filter.Eq(BsonId.Name, BsonValue.Create(value));
		}
		public static FilterDefinition<BsonDocument> FilterDefinitionOfInputId(object value)
		{
			value = Actor.BaseObject(value, out PSObject custom);
			if (custom == null)
			{
				if (value is IConvertibleToBsonDocument cd)
				{
					var doc = cd.ToBsonDocument();
					if (doc.TryGetElement(BsonId.Name, out BsonElement elem))
						return new BsonDocument(elem);
					else
						throw new InvalidOperationException(TextInputDocId);
				}

				if (value is IDictionary dic)
				{
					if (!dic.Contains(BsonId.Name))
						throw new InvalidOperationException(TextInputDocId);

					return FilterDefinitionOfId(dic[BsonId.Name]);
				}
			}

			var ps = custom ?? PSObject.AsPSObject(value);
			var pi = ps.Properties[BsonId.Name];
			if (pi == null)
				throw new InvalidOperationException(TextInputDocId);
			else
				return FilterDefinitionOfId(pi.Value);
		}
		public static SortDefinition<BsonDocument> SortDefinition(object value)
		{
			if (TryBsonDocumentOrNull(value, out var doc))
				return doc;

			return (SortDefinition<BsonDocument>)value;
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
				return new BsonDocument[] { Actor.ToBsonDocumentFromDictionary(dictionary) };

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
		public static ProjectionDefinition<BsonDocument> ProjectionDefinition(object value)
		{
			if (TryBsonDocumentOrNull(value, out var doc))
				return doc;

			return (ProjectionDefinition<BsonDocument>)value;
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
