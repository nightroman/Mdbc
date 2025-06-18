
using MongoDB.Bson;
using MongoDB.Bson.Serialization;
using MongoDB.Driver;
using System.Collections;
using System.Management.Automation;

namespace Mdbc;

public static class Api
{
	internal static GuidRepresentation GuidRepresentation => GuidRepresentation.Standard;

	static object BaseObjectNotNull(object value)
	{
		ArgumentNullException.ThrowIfNull(value);
		return value is PSObject ps ? ps.BaseObject : value;
	}

	/// <summary>
	/// JSON, IConvertibleToBsonDocument, IDictionary.
	/// </summary>
	internal static BsonDocument BsonDocument(object value)
	{
		// unwrap, it may be PSObject item of PS array, see _191103_084410
		value = BaseObjectNotNull(value);

		if (value is string json)
			return MyJson.ToBsonDocument(json);

		//! before IDictionary, mind Mdbc.Dictionary
		if (value is IConvertibleToBsonDocument cd)
			return cd.ToBsonDocument();

		//! after IConvertibleToBsonDocument
		if (value is IDictionary dictionary)
			return Actor.ToBsonDocumentFromDictionary(dictionary);

		throw new InvalidOperationException(Res.CannotConvert2(value.GetType(), nameof(BsonDocument)));
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
			result = MyJson.ToBsonDocument(json);
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

		value = value.ToBaseObject();

		if (value is string json)
		{
			result = json.Length == 0 ? null : MyJson.ToBsonDocument(json);
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
			if (doc.ElementCount == 0) throw new ArgumentException(Res.ErrorEmptyDocument);
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
		value = value.ToBaseObject();
		return Builders<BsonDocument>.Filter.Eq(BsonId.Name, BsonValue.Create(value));
	}

	public static FilterDefinition<BsonDocument> FilterDefinitionOfInputId(object value)
	{
		value = value.ToBaseObject(out PSObject custom);
		if (custom == null)
		{
			if (value is IConvertibleToBsonDocument cd)
			{
				var doc = cd.ToBsonDocument();
				if (doc.TryGetElement(BsonId.Name, out BsonElement elem))
					return new BsonDocument(elem);
				else
					throw new InvalidOperationException(Res.InputDocId);
			}

			if (value is IDictionary dic)
			{
				if (!dic.Contains(BsonId.Name))
					throw new InvalidOperationException(Res.InputDocId);

				var id = dic[BsonId.Name];
				return FilterDefinitionOfId(id);
			}

			if (Actor.TypeIsDriverSerialized(value.GetType()))
			{
				var cm = BsonClassMap.LookupClassMap(value.GetType());
				var mm = cm.GetMemberMapForElement(BsonId.Name);
				var id = mm.Getter(value);
				return FilterDefinitionOfId(id);
			}
		}

		var ps = custom ?? PSObject.AsPSObject(value);
		var pi = ps.Properties[BsonId.Name];
		if (pi == null)
			throw new InvalidOperationException(Res.InputDocId);
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
		return PipelineDefinition<BsonDocument, BsonDocument>(value);
	}

	internal static PipelineDefinition<TInput, TOutput> PipelineDefinition<TInput, TOutput>(object value)
	{
		value = BaseObjectNotNull(value);

		// JSON first because it looks very convenient for pipelines
		if (value is string json)
		{
			var bson = MyJson.ToBsonValue(json);
			return bson.BsonType switch
			{
				BsonType.Array => (PipelineDefinition<TInput, TOutput>)bson.AsBsonArray.Select(x => x.AsBsonDocument).ToList(),
				BsonType.Document => (PipelineDefinition<TInput, TOutput>)(new BsonDocument[] { bson.AsBsonDocument }),
				_ => throw new ArgumentException($"JSON: expected array or document, found {bson.BsonType}."),
			};
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
		return (PipelineDefinition<TInput, TOutput>)value;
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
			if (doc.ElementCount == 0) throw new ArgumentException(Res.ErrorEmptyDocument);
			return doc;
		}

		if (value is IEnumerable)
			return PipelineDefinition(value);

		return (UpdateDefinition<BsonDocument>)value;
	}
}
