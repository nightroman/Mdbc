
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System;
using System.Collections.Generic;
using System.Management.Automation;
using MongoDB.Bson;

namespace Mdbc.Commands;

[Cmdlet(VerbsCommon.New, "MdbcData"), OutputType(typeof(Dictionary))]
public sealed class NewDataCommand : Abstract
{
	[Parameter(Position = 0, ValueFromPipeline = true)]
	public object InputObject { get; set; }

	[Parameter]
	public object Id { get; set; }

	[Parameter]
	public SwitchParameter NewId { get; set; }

	[Parameter]
	public ScriptBlock Convert { get; set; }

	[Parameter]
	public object[] Property { set { if (value == null) throw new PSArgumentNullException(nameof(value)); _Selectors = Selector.Create(value); } }
	IList<Selector> _Selectors;

	protected override void ProcessRecord()
	{
		try
		{
			// always new document
			var document = DocumentInput.NewDocumentWithId(NewId, Id, InputObject) ?? [];

			if (InputObject != null)
				document = Actor.ToBsonDocument(document, InputObject, Convert, _Selectors);

			WriteObject(new Dictionary(document));
		}
		catch (ArgumentException ex)
		{
			WriteError(DocumentInput.NewErrorRecordBsonValue(ex, InputObject));
		}
	}
}
