
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

//! Do not expose `KnownTypes`, it is not useful in Mdbc because we require all types registered, i.e. "known".

using MongoDB.Bson.Serialization;
using System;
using System.Management.Automation;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsLifecycle.Register, "MdbcClassMap", DefaultParameterSetName = psMain)]
	public sealed class RegisterClassMapCommand : Abstract
	{
		const string psMain = "Main";
		const string psForce = "Force";

		[Parameter(Position = 0, Mandatory = true)]
		public Type Type { get; set; }

		[Parameter(Mandatory = true, ParameterSetName = psForce)]
		public SwitchParameter Force { get; set; }

		[Parameter(ParameterSetName = psMain)]
		public ScriptBlock Init { get; set; }

		[Parameter(ParameterSetName = psMain)]
		public string IdProperty { get; set; }

		[Parameter(ParameterSetName = psMain)]
		public string Discriminator { get; set; }

		[Parameter(ParameterSetName = psMain)]
		public SwitchParameter DiscriminatorIsRequired { get; set; }

		[Parameter(ParameterSetName = psMain)]
		public string ExtraElementsProperty { get; set; }

		[Parameter(ParameterSetName = psMain)]
		public SwitchParameter IgnoreExtraElements { get; set; }

		protected override void BeginProcessing()
		{
			// | registered by Mdbc
			if (ClassMap.Contains(Type))
			{
				WriteVerbose($"Type {Type} was registered by Mdbc, doing nothing.");
				return;
			}

			// | registered by driver
			if (BsonClassMap.IsClassMapRegistered(Type))
			{
				if (ParameterSetName != psForce)
				{
					WriteException(new PSInvalidOperationException("Class map is registered by driver. If this is expected invoke with just -Type and -Force."), Type);
					return;
				}

				WriteVerbose($"Type {Type} was registered by driver, registering by Mdbc.");
				ClassMap.Add(Type);
				return;
			}

			try
			{
				var cm = new BsonClassMap(Type);
				if (Init == null)
				{
					cm.AutoMap();
				}
				else
				{
					var res = PS2.InvokeWithContext(Init, cm);
					if (res.Count > 0)
						throw new PSArgumentException("The Init script must not return anything.");
				}

				if (IdProperty != null)
					cm.MapIdProperty(IdProperty);

				if (Discriminator != null)
					cm.SetDiscriminator(Discriminator);
				if (DiscriminatorIsRequired)
					cm.SetDiscriminatorIsRequired(true);

				if (IgnoreExtraElements)
					cm.SetIgnoreExtraElements(IgnoreExtraElements);
				if (ExtraElementsProperty != null)
					cm.MapExtraElementsProperty(ExtraElementsProperty);

				// in theory, may throw if the map is registered in another thread
				BsonClassMap.RegisterClassMap(cm);

				// done
				ClassMap.Add(Type);
			}
			catch (ArgumentException exn)
			{
				WriteException(exn, Type);
			}
		}
	}
}
