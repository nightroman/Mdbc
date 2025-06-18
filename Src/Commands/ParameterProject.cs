
using MongoDB.Bson;
using MongoDB.Bson.Serialization;
using MongoDB.Driver;
using System.Management.Automation;

namespace Mdbc.Commands;

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
		value = value.ToBaseObject();
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
