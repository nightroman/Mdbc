
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System;
using System.Collections.Generic;
using System.Management.Automation;
using MongoDB.Bson;

namespace Mdbc
{
	//_131102_084424 Unwraps PSObject's like Get-Date.
	class PSObjectTypeMapper : ICustomBsonTypeMapper
	{
		public bool TryMapToBsonValue(object value, out BsonValue bsonValue)
		{
			var ps = value as PSObject;
			if (ps != null)
				return BsonTypeMapper.TryMapToBsonValue(ps.BaseObject, out bsonValue);
			bsonValue = null;
			return false;
		}
	}
	class ParameterAs
	{
		internal readonly Type Type;
		public ParameterAs(PSObject value)
		{
			if (value == null)
			{
				Type = typeof(Dictionary);
				return;
			}

			var type = value.BaseObject as Type;
			if (type != null)
			{
				Type = (Type)LanguagePrimitives.ConvertTo(value, typeof(Type), null);
				return;
			}

			switch ((OutputType)LanguagePrimitives.ConvertTo(value, typeof(OutputType), null))
			{
				case OutputType.Default:
					Type = typeof(Dictionary);
					return;
				case OutputType.PS:
					Type = typeof(PSObject);
					return;
			}
		}
	}
	static class MyValue
	{
		public const string Id = "_id";
	}
}
