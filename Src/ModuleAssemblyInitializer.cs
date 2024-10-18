
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Bson;
using MongoDB.Bson.IO;
using MongoDB.Bson.Serialization;
using MongoDB.Bson.Serialization.Serializers;
using System;
using System.Management.Automation;

namespace Mdbc;

public class ModuleAssemblyInitializer : IModuleAssemblyInitializer
{
	//! may be called twice, e.g. `ib Retry Export.test.ps1`, so use the static constructor
	public void OnImport()
	{
	}

	static ModuleAssemblyInitializer()
	{
		// Changed from Shell to RelaxedExtendedJson in 3.0, not useful for interactive `ToString()`, etc.
		if (!JsonWriterSettings.Defaults.IsFrozen)
			JsonWriterSettings.Defaults.OutputMode = JsonOutputMode.Shell;

		BsonSerializer.RegisterSerializer(typeof(Dictionary), new DictionarySerializer());
		BsonSerializer.RegisterSerializer(typeof(Collection), new CollectionSerializer());
		BsonSerializer.RegisterSerializer(typeof(Guid), new GuidSerializer(Api.GuidRepresentation));
		BsonSerializer.RegisterSerializer(typeof(PSObject), new PSObjectSerializer());
		BsonSerializer.RegisterSerializer(typeof(object), new ObjectSerializer(ObjectSerializer.Instance.DiscriminatorConvention, Api.GuidRepresentation));

		BsonTypeMapper.RegisterCustomTypeMapper(typeof(Guid), new GuidTypeMapper());
		BsonTypeMapper.RegisterCustomTypeMapper(typeof(PSObject), new PSObjectTypeMapper());
	}
}
