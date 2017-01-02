
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System;
using System.Collections.Generic;
using System.Management.Automation;
using MongoDB.Bson;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsCommon.New, "MdbcData", DefaultParameterSetName = nsDocument)]
	public sealed class NewDataCommand : Abstract
	{
		const string nsDocument = "Document";
		const string nsValue = "Value";

		[Parameter(ParameterSetName = nsValue)]
		public PSObject Value { get; set; }

		[Parameter(Position = 0, ValueFromPipeline = true, ParameterSetName = nsDocument)]
		public PSObject InputObject { get; set; }

		[Parameter(ParameterSetName = nsDocument)]
		public PSObject Id { get; set; }

		[Parameter(ParameterSetName = nsDocument)]
		public SwitchParameter NewId { get; set; }

		[Parameter(ParameterSetName = nsDocument)]
		public ScriptBlock Convert { get; set; }

		[Parameter(ParameterSetName = nsDocument)]
		public object[] Property { get { return null; } set { _Selectors = Selector.Create(value, this); } }
		IList<Selector> _Selectors;

		protected override void ProcessRecord()
		{
			try
			{
				if (ParameterSetName == nsValue)
				{
					WriteObject(Actor.ToBsonValue(Value));
					return;
				}

				// always new document
				var document = DocumentInput.NewDocumentWithId(NewId, Id, InputObject, SessionState) ?? new BsonDocument();

				if (InputObject != null)
					document = Actor.ToBsonDocument(document, InputObject, new DocumentInput(SessionState, Convert), _Selectors);

				WriteObject(new Dictionary(document));
			}
			catch (ArgumentException ex)
			{
				WriteError(DocumentInput.NewErrorRecordBsonValue(ex, InputObject));
			}
		}
	}
}
