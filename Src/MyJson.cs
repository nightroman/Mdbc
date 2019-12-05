
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Bson;
using MongoDB.Bson.IO;
using MongoDB.Bson.Serialization;
using MongoDB.Bson.Serialization.Serializers;
using System;
using System.Diagnostics;
using System.IO;

// NB: Change of the global defaults affects ToString(). `Strict` (like
// mongoexport) is tempting, other tools may read it. But `Strict` is not
// suitable for reading and searching. Also, it looses number types (numbers
// are double). `Shell` (default) keeps types and readable for _id, dates,
// GUID. Let's use `Shell` not directly but via defaults.

namespace Mdbc
{
	static class MyJson
	{
		public static JsonWriterSettings DefaultJsonWriterSettings
		{
			get { return JsonWriterSettings.Defaults; }
		}
		internal static BsonValue ToBsonValue(string json)
		{
			Debug.Assert(json != null);
			try
			{
				var serializer = BsonValueSerializer.Instance;
				using (var reader1 = new StringReader(json))
				{
					using (var reader2 = new JsonReader(reader1))
					{
						var context = BsonDeserializationContext.CreateRoot(reader2);
						return serializer.Deserialize(context);
					}
				}
			}
			catch (Exception exn)
			{
				throw new ArgumentException("Invalid JSON.", exn);
			}
		}
		internal static BsonDocument ToBsonDocument(string json)
		{
			var bson = ToBsonValue(json);
			if (bson.BsonType == BsonType.Document)
				return bson.AsBsonDocument;
			else
				throw new ArgumentException($"JSON: expected document, found {bson.BsonType}.");
		}
		internal static string PrintBsonDocument(BsonDocument value)
		{
			var stringWriter = new StringWriter();
			var args = new JsonWriterSettings() { Indent = true };
			using (var jsonWriter = new JsonWriter(stringWriter, args))
			{
				var context = BsonSerializationContext.CreateRoot(jsonWriter);
				BsonDocumentSerializer.Instance.Serialize(context, value);
			}
			return stringWriter.ToString();
		}
	}
}
