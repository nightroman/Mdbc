
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Bson;
using MongoDB.Bson.Serialization;
using MongoDB.Driver;
using System;
using System.Collections.Generic;
using System.Management.Automation;

namespace Mdbc
{
	static class ClassMap
	{
		static readonly HashSet<Type> _types = new HashSet<Type>();
		internal static void Add(Type type)
		{
			_types.Add(type);
		}
		internal static bool Contains(Type type)
		{
			return _types.Contains(type);
		}
	}
	//_131102_084424 Unwraps PSObject's like Get-Date.
	class PSObjectTypeMapper : ICustomBsonTypeMapper
	{
		public bool TryMapToBsonValue(object value, out BsonValue bsonValue)
		{
			bsonValue = Actor.ToBsonValue(value);
			return true;
		}
	}
	class ParameterAs
	{
		internal Type Type = typeof(Dictionary);
		internal bool IsSet;
		internal bool IsType;

		internal ParameterAs() { }

		internal void Set(object value)
		{
			value = Actor.BaseObject(value);
			if (value == null)
				return;

			IsSet = true;

			if (value is Type type)
			{
				IsType = true;
				Type = type;
				return;
			}

			if (LanguagePrimitives.TryConvertTo(value, out OutputType alias))
			{
				switch (alias)
				{
					case OutputType.Default:
						Type = typeof(Dictionary);
						return;
					case OutputType.PS:
						Type = typeof(PSObject);
						return;
				}
			}

			Type = (Type)LanguagePrimitives.ConvertTo(value, typeof(Type), null);
			IsType = true;
		}
	}
	class ParameterProject
	{
		ProjectionDefinition<BsonDocument> _Project;
		bool _IsAll;

		internal ParameterProject() { }

		internal void Set(object value)
		{
			value = Actor.BaseObject(value);
			if (value is string s && s == "*")
				_IsAll = true;
			else
				_Project = Api.ProjectionDefinition(value);
		}

		internal ProjectionDefinition<BsonDocument> Get(ParameterAs paramAs)
		{
			if (_Project == null && _IsAll && paramAs.IsSet && paramAs.IsType)
			{
				BsonClassMap cm;
				if (BsonClassMap.IsClassMapRegistered(paramAs.Type))
				{
					cm = BsonClassMap.LookupClassMap(paramAs.Type);
				}
				else
				{
					cm = new BsonClassMap(paramAs.Type);
					cm.AutoMap();
					cm = cm.Freeze();
				}

				if (cm.ExtraElementsMemberMap == null)
				{
					var hasId = false;
					var project = new BsonDocument();
					foreach (var m in cm.AllMemberMaps)
					{
						project.Add(m.ElementName, new BsonInt32(1));
						if (m.ElementName == MyValue.Id)
							hasId = true;
					}
					if (!hasId)
						project.Add(MyValue.Id, new BsonInt32(0));
					_Project = project;
				}
			}
			return _Project;
		}
	}
	static class MyValue
	{
		public const string Id = "_id";
	}
}
