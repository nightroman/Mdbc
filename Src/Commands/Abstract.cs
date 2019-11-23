
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Bson;
using MongoDB.Bson.Serialization;
using MongoDB.Driver;
using System;
using System.Management.Automation;

namespace Mdbc.Commands
{
	/// <summary>
	/// Common base class for all Mdbc commands.
	/// </summary>
	public abstract class Abstract : PSCmdlet
	{
		protected void WriteException(Exception exception, object target)
		{
			WriteError(new ErrorRecord(exception, "Mdbc", ErrorCategory.NotSpecified, target));
		}
	}
	/// <summary>
	/// Common parameter -As.
	/// </summary>
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
	/// <summary>
	/// Common parameter -Project.
	/// </summary>
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
						project.Add(m.ElementName, BsonBoolean.True);
						if (m.ElementName == BsonId.Name)
							hasId = true;
					}
					if (!hasId)
						project.Add(BsonId.Element(BsonBoolean.False));
					_Project = project;
				}
			}
			return _Project;
		}
	}
}
