
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System;
using System.Collections;
using System.Management.Automation;
using MongoDB.Bson;
using MongoDB.Bson.IO;
using MongoDB.Bson.Serialization;
using MongoDB.Bson.Serialization.Serializers;

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
		static object ReadObject(IBsonReader bsonReader) //_120509_173140 keep consistent
		{
			switch (bsonReader.GetCurrentBsonType())
			{
				case BsonType.Array: return ReadArray(bsonReader); // replacement
				case BsonType.Binary: var binary = BsonSerializer.Deserialize<BsonValue>(bsonReader); return BsonTypeMapper.MapToDotNetValue(binary) ?? binary; // byte[] or Guid else self
				case BsonType.Boolean: return bsonReader.ReadBoolean();
				case BsonType.DateTime: return BsonUtils.ToDateTimeFromMillisecondsSinceEpoch(bsonReader.ReadDateTime());
				case BsonType.Document: return ReadCustomObject(bsonReader); // replacement
				case BsonType.Double: return bsonReader.ReadDouble();
				case BsonType.Int32: return bsonReader.ReadInt32();
				case BsonType.Int64: return bsonReader.ReadInt64();
				case BsonType.Null: bsonReader.ReadNull(); return null;
				case BsonType.ObjectId: return bsonReader.ReadObjectId();
				case BsonType.String: return bsonReader.ReadString();
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
	}
	sealed class LazyDictionarySerializer : SealedClassSerializerBase<LazyDictionary>
	{
		public override LazyDictionary Deserialize(BsonDeserializationContext context, BsonDeserializationArgs args)
        {
            var serialiazer = new LazyBsonDocumentSerializer();
            return new LazyDictionary(serialiazer.Deserialize(context, args));
		}
	}
	sealed class RawDictionarySerializer : SealedClassSerializerBase<RawDictionary>
    {
		public override RawDictionary Deserialize(BsonDeserializationContext context, BsonDeserializationArgs args)
		{
            return new RawDictionary(RawBsonDocumentSerializer.Instance.Deserialize(context, args));
		}
	}
}
