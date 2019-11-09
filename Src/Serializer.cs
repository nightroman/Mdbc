
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Bson;
using MongoDB.Bson.IO;
using MongoDB.Bson.Serialization;
using MongoDB.Bson.Serialization.Serializers;
using System.Collections;
using System.Management.Automation;

namespace Mdbc
{
	sealed class PSObjectSerializer : SealedClassSerializerBase<PSObject>
	{
		static IList ReadArray(IBsonReader bsonReader)
		{
			var array = new ArrayList();

			bsonReader.ReadStartArray();
			while (bsonReader.ReadBsonType() != BsonType.EndOfDocument)
				array.Add(ReadObject(bsonReader));
			bsonReader.ReadEndArray();

			return array;
		}
		static object ReadObject(IBsonReader bsonReader) //_120509_173140 sync, test
		{
			switch (bsonReader.GetCurrentBsonType())
			{
				case BsonType.Array: return ReadArray(bsonReader); // replacement
				case BsonType.Boolean: return bsonReader.ReadBoolean();
				case BsonType.DateTime: return BsonUtils.ToDateTimeFromMillisecondsSinceEpoch(bsonReader.ReadDateTime());
				case BsonType.Decimal128: return Decimal128.ToDecimal(bsonReader.ReadDecimal128());
				case BsonType.Document: return ReadCustomObject(bsonReader); // replacement
				case BsonType.Double: return bsonReader.ReadDouble();
				case BsonType.Int32: return bsonReader.ReadInt32();
				case BsonType.Int64: return bsonReader.ReadInt64();
				case BsonType.Null: bsonReader.ReadNull(); return null;
				case BsonType.ObjectId: return bsonReader.ReadObjectId();
				case BsonType.String: return bsonReader.ReadString();
				case BsonType.Binary:
					var data = bsonReader.ReadBinaryData();
					switch (data.SubType)
					{
						case BsonBinarySubType.UuidLegacy:
						case BsonBinarySubType.UuidStandard:
							return data.ToGuid();
						default:
							return data;
					}
				default: return BsonSerializer.Deserialize<BsonValue>(bsonReader);
			}
		}
		static PSObject ReadCustomObject(IBsonReader bsonReader)
		{
			var ps = new PSObject();
			var properties = ps.Properties;

			bsonReader.ReadStartDocument();
			while (bsonReader.ReadBsonType() != BsonType.EndOfDocument)
			{
				var name = bsonReader.ReadName();
				var value = ReadObject(bsonReader);
				properties.Add(new PSNoteProperty(name, value), true); //! true is faster
			}
			bsonReader.ReadEndDocument();

			return ps;
		}
		public override PSObject Deserialize(BsonDeserializationContext context, BsonDeserializationArgs args)
		{
			return ReadCustomObject(context.Reader);
		}
	}
	sealed class DictionarySerializer : SealedClassSerializerBase<Dictionary>
	{
		public override Dictionary Deserialize(BsonDeserializationContext context, BsonDeserializationArgs args)
		{
			return new Dictionary(BsonDocumentSerializer.Instance.Deserialize(context, args));
		}
		public override void Serialize(BsonSerializationContext context, BsonSerializationArgs args, Dictionary value)
		{
			BsonDocumentSerializer.Instance.Serialize(context, args, value.ToBsonDocument());
		}
	}
	sealed class CollectionSerializer : SealedClassSerializerBase<Collection>
	{
		public override Collection Deserialize(BsonDeserializationContext context, BsonDeserializationArgs args)
		{
			return new Collection(BsonArraySerializer.Instance.Deserialize(context, args));
		}
		public override void Serialize(BsonSerializationContext context, BsonSerializationArgs args, Collection value)
		{
			BsonArraySerializer.Instance.Serialize(context, args, value.ToBsonArray());
		}
	}
}
