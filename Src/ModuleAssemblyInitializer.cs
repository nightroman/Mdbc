
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Bson;
using MongoDB.Bson.Serialization;
using System;
using System.IO;
using System.Management.Automation;
using System.Reflection;

namespace Mdbc;

public class ModuleAssemblyInitializer : IModuleAssemblyInitializer
{
	//! may be called twice, e.g. `ib Retry Export.test.ps1`, so use the static constructor
	public void OnImport()
	{
	}

	static ModuleAssemblyInitializer()
	{
		AppDomain.CurrentDomain.AssemblyResolve += AssemblyResolve;

		BsonSerializer.RegisterSerializer(typeof(Collection), new CollectionSerializer());
		BsonSerializer.RegisterSerializer(typeof(Dictionary), new DictionarySerializer());
		BsonSerializer.RegisterSerializer(typeof(PSObject), new PSObjectSerializer());

		BsonTypeMapper.RegisterCustomTypeMapper(typeof(PSObject), new PSObjectTypeMapper());

		var strGuidRepresentation = Environment.GetEnvironmentVariable("Mdbc_GuidRepresentation");
#pragma warning disable 618 // obsolete BsonDefaults.GuidRepresentation
		if (strGuidRepresentation == null)
		{
			BsonDefaults.GuidRepresentation = GuidRepresentation.Standard;
		}
		else
		{
			if (Enum.TryParse(strGuidRepresentation, out GuidRepresentation valGuidRepresentation))
				BsonDefaults.GuidRepresentation = valGuidRepresentation;
			else
				throw new InvalidOperationException($"Invalid environment variable Mdbc_GuidRepresentation = {strGuidRepresentation}");
		}
#pragma warning restore 618
	}

	// Workaround for Desktop
	static Assembly AssemblyResolve(object sender, ResolveEventArgs args)
	{
		if (args.Name.StartsWith("System.Runtime.CompilerServices.Unsafe"))
		{
			var root = Path.GetDirectoryName(typeof(ModuleAssemblyInitializer).Assembly.Location);
			var path = Path.Combine(root, "System.Runtime.CompilerServices.Unsafe.dll");
			var assembly = Assembly.LoadFrom(path);
			return assembly;
		}
		return null;
	}
}
