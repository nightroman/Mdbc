
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Bson;
using MongoDB.Bson.Serialization;
using System;
using System.Management.Automation;

namespace Mdbc
{
	public class ModuleAssemblyInitializer : IModuleAssemblyInitializer
	{
		static bool _called;

		// This method is called on Import-Module.
		public void OnImport()
		{
			if (_called)
				return;
			_called = true;

			BsonSerializer.RegisterSerializer(typeof(Collection), new CollectionSerializer());
			BsonSerializer.RegisterSerializer(typeof(Dictionary), new DictionarySerializer());
			BsonSerializer.RegisterSerializer(typeof(PSObject), new PSObjectSerializer());

			BsonTypeMapper.RegisterCustomTypeMapper(typeof(PSObject), new PSObjectTypeMapper());

			var strGuidRepresentation = Environment.GetEnvironmentVariable("Mdbc_GuidRepresentation");
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
		}
	}
}
