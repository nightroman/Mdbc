
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Bson;
using MongoDB.Driver;
using System;
using System.Collections.Generic;
using System.Management.Automation;

namespace Mdbc.Commands
{
	[Cmdlet(VerbsCommon.Add, "MdbcData")]
	public sealed class AddDataCommand : AbstractCollectionCommand
	{
		[Parameter(Position = 0, ValueFromPipeline = true)]
		public PSObject InputObject { get; set; }

		[Parameter]
		public PSObject Id { get; set; }

		[Parameter]
		public SwitchParameter NewId { get; set; }

		[Parameter]
		public ScriptBlock Convert { get; set; }

		[Parameter]
		public object[] Property { set { if (value == null) throw new PSArgumentNullException(nameof(value)); _Selectors = Selector.Create(value); } }
		IList<Selector> _Selectors;

		protected override void ProcessRecord()
		{
			if (InputObject == null)
				return;

			try
			{
				// new document or none yet
				var document = DocumentInput.NewDocumentWithId(NewId, Id, InputObject);

				document = Actor.ToBsonDocument(document, InputObject, Convert, _Selectors);
				Collection.InsertOne(Session, document);
			}
			catch (ArgumentException ex)
			{
				WriteError(DocumentInput.NewErrorRecordBsonValue(ex, InputObject));
			}
			catch (MongoException ex)
			{
				WriteException(ex, InputObject);
			}
		}
	}
}
